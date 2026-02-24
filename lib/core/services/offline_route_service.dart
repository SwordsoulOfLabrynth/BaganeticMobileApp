import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/helpers.dart';

// Conditional import for File - only import on non-web
import 'dart:io' if (dart.library.html) 'dart:html' show File;

class OfflineRouteService {
  OfflineRouteService._();

  static final OfflineRouteService instance = OfflineRouteService._();

  static const String _graphFileName = 'offline_route_graph.json';
  static const String _metaFileName = 'offline_route_meta.json';
  Timer? _syncTimer;

  Future<void> startBackgroundSync() async {
    await _syncIfNeeded();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      AppConstants.offlineGraphSyncInterval,
      (_) => _syncIfNeeded(),
    );
  }

  Future<List<LatLng>> buildRouteForPoints(List<LatLng> points) async {
    if (points.length < 2) return [];
    final graph = await loadGraph();
    if (graph == null) {
      return _buildFallbackRoute(points);
    }
    return _buildRouteWithGraph(graph, points);
  }

  Future<OfflineGraphData?> loadGraph() async {
    if (kIsWeb) {
      // On web, always use bundled graph
      return _loadBundledGraph();
    }
    final file = await _getGraphFile();
    if (!await file.exists()) {
      return _loadBundledGraph();
    }
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return OfflineGraphData.fromJson(data);
    } catch (_) {
      return _loadBundledGraph();
    }
  }

  Future<void> _syncIfNeeded() async {
    if (kIsWeb) {
      // On web, skip file-based sync
      return;
    }
    try {
      if (AppConstants.offlineGraphUrl.isEmpty) {
        return;
      }
      final meta = await _readMeta();
      if (meta != null) {
        final age = DateTime.now().difference(meta.lastSync);
        if (age < AppConstants.offlineGraphSyncInterval) {
          return;
        }
      }

      final response = await http.get(Uri.parse(AppConstants.offlineGraphUrl));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final graph = OfflineGraphData.fromJson(data);

      final localVersion = meta?.version ?? 0;
      if (graph.version <= localVersion) {
        await _writeMeta(
          OfflineGraphMeta(version: localVersion, lastSync: DateTime.now()),
        );
        return;
      }

      final file = await _getGraphFile();
      await file.writeAsString(response.body);
      await _writeMeta(
        OfflineGraphMeta(version: graph.version, lastSync: DateTime.now()),
      );
    } catch (_) {
      // Silent background failure.
    }
  }

  Future<OfflineGraphData?> _loadBundledGraph() async {
    try {
      final raw = await rootBundle.loadString('assets/data/offline_graph.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return OfflineGraphData.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<File> _getGraphFile() async {
    if (kIsWeb) {
      throw UnsupportedError('File operations not supported on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_graphFileName');
  }

  Future<File> _getMetaFile() async {
    if (kIsWeb) {
      throw UnsupportedError('File operations not supported on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  Future<OfflineGraphMeta?> _readMeta() async {
    final file = await _getMetaFile();
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return OfflineGraphMeta.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta(OfflineGraphMeta meta) async {
    final file = await _getMetaFile();
    await file.writeAsString(jsonEncode(meta.toJson()));
  }

  List<LatLng> _buildRouteWithGraph(
    OfflineGraphData graph,
    List<LatLng> points,
  ) {
    final snapped = points.map(graph.findNearestNode).toList();
    final route = <LatLng>[];

    for (int i = 0; i < snapped.length - 1; i++) {
      final startPoint = points[i];
      final endPoint = points[i + 1];
      final segment = _findPath(graph, snapped[i], snapped[i + 1]);
      final resolved = segment.isEmpty
          ? _buildCurvedFallback(startPoint, endPoint)
          : segment;
      if (resolved.isEmpty) return [];
      final withEndpoints = _attachEndpoints(
        graph,
        resolved,
        startPoint,
        endPoint,
      );
      if (route.isNotEmpty) {
        route.addAll(withEndpoints.sublist(1));
      } else {
        route.addAll(withEndpoints);
      }
    }

    return route;
  }

  List<LatLng> _buildFallbackRoute(List<LatLng> points) {
    final route = <LatLng>[];
    for (int i = 0; i < points.length - 1; i++) {
      final segment = _buildCurvedFallback(points[i], points[i + 1]);
      if (segment.isEmpty) return [];
      if (route.isNotEmpty) {
        route.addAll(segment.sublist(1));
      } else {
        route.addAll(segment);
      }
    }
    return route;
  }

  List<LatLng> _attachEndpoints(
    OfflineGraphData graph,
    List<LatLng> segment,
    LatLng start,
    LatLng end,
  ) {
    if (segment.isEmpty) return segment;

    final startNode = segment.first;
    final endNode = segment.last;
    final startGap = Helpers.calculateDistance(
      start.latitude,
      start.longitude,
      startNode.latitude,
      startNode.longitude,
    );
    final endGap = Helpers.calculateDistance(
      end.latitude,
      end.longitude,
      endNode.latitude,
      endNode.longitude,
    );

    final result = <LatLng>[];
    if (startGap > 0.15) {
      result.addAll(_buildCurvedFallback(start, startNode));
    } else {
      result.add(start);
    }

    if (result.isNotEmpty) {
      result.addAll(segment.sublist(1));
    } else {
      result.addAll(segment);
    }

    if (endGap > 0.15) {
      final bridge = _buildCurvedFallback(endNode, end);
      if (bridge.isNotEmpty) {
        result.addAll(bridge.sublist(1));
      }
    } else {
      result.add(end);
    }

    return result;
  }

  List<LatLng> _findPath(
    OfflineGraphData graph,
    String startId,
    String goalId,
  ) {
    if (startId == goalId) {
      final node = graph.nodes[startId];
      return node == null ? [] : [LatLng(node.lat, node.lng)];
    }

    final gScores = <String, double>{};
    final previous = <String, String?>{};
    final queue = _PriorityQueue<_QueueItem>((a, b) => a.cost.compareTo(b.cost));

    gScores[startId] = 0;
    queue.add(_QueueItem(startId, _heuristic(graph, startId, goalId)));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final currentG = gScores[current.nodeId];
      if (currentG == null) {
        continue;
      }
      final currentF = currentG + _heuristic(graph, current.nodeId, goalId);
      if (current.cost > currentF) {
        // Stale queue item.
        continue;
      }
      if (current.nodeId == goalId) {
        return _reconstructRoute(graph, previous, startId, goalId);
      }

      final neighbors = graph.adjacency[current.nodeId] ?? const [];
      for (final edge in neighbors) {
        final next = edge.to;
        final tentative = currentG + edge.weight;

        if (tentative < (gScores[next] ?? double.infinity)) {
          gScores[next] = tentative;
          previous[next] = current.nodeId;
          final fScore = tentative + _heuristic(graph, next, goalId);
          queue.add(_QueueItem(next, fScore));
        }
      }
    }

    return [];
  }

  double _heuristic(OfflineGraphData graph, String fromId, String goalId) {
    final fromNode = graph.nodes[fromId];
    final goalNode = graph.nodes[goalId];
    if (fromNode == null || goalNode == null) {
      return 0;
    }
    return Helpers.calculateDistance(
      fromNode.lat,
      fromNode.lng,
      goalNode.lat,
      goalNode.lng,
    );
  }

  double? estimateGraphDistance(
    OfflineGraphData graph,
    LatLng start,
    LatLng end,
  ) {
    final startId = graph.findNearestNode(start);
    final goalId = graph.findNearestNode(end);
    if (startId.isEmpty || goalId.isEmpty) {
      return null;
    }

    final startNode = graph.nodes[startId];
    final goalNode = graph.nodes[goalId];
    if (startNode == null || goalNode == null) {
      return null;
    }

    final pathDistance = _findPathDistance(graph, startId, goalId);
    if (pathDistance == null) {
      return null;
    }

    final startGap = Helpers.calculateDistance(
      start.latitude,
      start.longitude,
      startNode.lat,
      startNode.lng,
    );
    final endGap = Helpers.calculateDistance(
      end.latitude,
      end.longitude,
      goalNode.lat,
      goalNode.lng,
    );

    return pathDistance + startGap + endGap;
  }

  double? _findPathDistance(
    OfflineGraphData graph,
    String startId,
    String goalId,
  ) {
    if (startId == goalId) {
      return 0;
    }

    final gScores = <String, double>{};
    final queue = _PriorityQueue<_QueueItem>((a, b) => a.cost.compareTo(b.cost));

    gScores[startId] = 0;
    queue.add(_QueueItem(startId, _heuristic(graph, startId, goalId)));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final currentG = gScores[current.nodeId];
      if (currentG == null) {
        continue;
      }
      final currentF = currentG + _heuristic(graph, current.nodeId, goalId);
      if (current.cost > currentF) {
        continue;
      }
      if (current.nodeId == goalId) {
        return currentG;
      }

      final neighbors = graph.adjacency[current.nodeId] ?? const [];
      for (final edge in neighbors) {
        final next = edge.to;
        final tentative = currentG + edge.weight;

        if (tentative < (gScores[next] ?? double.infinity)) {
          gScores[next] = tentative;
          final fScore = tentative + _heuristic(graph, next, goalId);
          queue.add(_QueueItem(next, fScore));
        }
      }
    }

    return null;
  }

  List<LatLng> _reconstructRoute(
    OfflineGraphData graph,
    Map<String, String?> previous,
    String startId,
    String goalId,
  ) {
    final path = <String>[];
    String? current = goalId;
    while (current != null) {
      path.insert(0, current);
      if (current == startId) break;
      current = previous[current];
    }

    if (path.isEmpty || path.first != startId) return [];

    final points = <LatLng>[];
    for (int i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final edge = graph.edgeBetween(from, to);
      final segment = edge?.shape?.isNotEmpty == true
          ? edge!.shape!
          : _fallbackSegment(graph, from, to);

      if (points.isNotEmpty && segment.isNotEmpty) {
        points.addAll(segment.sublist(1));
      } else {
        points.addAll(segment);
      }
    }

    return points;
  }

  List<LatLng> _fallbackSegment(
    OfflineGraphData graph,
    String from,
    String to,
  ) {
    final fromNode = graph.nodes[from];
    final toNode = graph.nodes[to];
    if (fromNode == null || toNode == null) return [];
    return [
      LatLng(fromNode.lat, fromNode.lng),
      LatLng(toNode.lat, toNode.lng),
    ];
  }

  List<LatLng> _buildCurvedFallback(LatLng start, LatLng end) {
    final distanceKm = Helpers.calculateDistance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final steps = 10;
    final latMid = (start.latitude + end.latitude) / 2;
    final lonMid = (start.longitude + end.longitude) / 2;
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      return [start, end];
    }

    final offsetKm = (distanceKm / 4).clamp(0.2, 1.2);
    final latOffset = offsetKm / 111.0;
    final lonOffset = offsetKm / (111.0 * math.cos(latMid * math.pi / 180));

    final perpX = -dy / length;
    final perpY = dx / length;
    final control = LatLng(
      latMid + perpY * latOffset,
      lonMid + perpX * lonOffset,
    );

    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final oneMinus = 1 - t;
      final lat = oneMinus * oneMinus * start.latitude +
          2 * oneMinus * t * control.latitude +
          t * t * end.latitude;
      final lon = oneMinus * oneMinus * start.longitude +
          2 * oneMinus * t * control.longitude +
          t * t * end.longitude;
      points.add(LatLng(lat, lon));
    }

    return points;
  }
}

class OfflineGraphData {
  final int version;
  final Map<String, OfflineGraphNode> nodes;
  final Map<String, List<OfflineGraphEdge>> adjacency;

  OfflineGraphData({
    required this.version,
    required this.nodes,
    required this.adjacency,
  });

  factory OfflineGraphData.fromJson(Map<String, dynamic> json) {
    final nodesList = (json['nodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(OfflineGraphNode.fromJson)
        .toList();
    final nodes = {for (final node in nodesList) node.id: node};

    final edgesList = (json['edges'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(OfflineGraphEdge.fromJson)
        .toList();

    final adjacency = <String, List<OfflineGraphEdge>>{};
    for (final edge in edgesList) {
      adjacency.putIfAbsent(edge.from, () => []).add(edge);
      if (!edge.oneWay) {
        adjacency
            .putIfAbsent(edge.to, () => [])
            .add(edge.reversed());
      }
    }

    return OfflineGraphData(
      version: json['version'] as int? ?? 0,
      nodes: nodes,
      adjacency: adjacency,
    );
  }

  String findNearestNode(LatLng point) {
    String? nearestId;
    double best = double.infinity;
    for (final node in nodes.values) {
      final distance = Helpers.calculateDistance(
        point.latitude,
        point.longitude,
        node.lat,
        node.lng,
      );
      if (distance < best) {
        best = distance;
        nearestId = node.id;
      }
    }
    return nearestId ?? nodes.keys.first;
  }

  OfflineGraphEdge? edgeBetween(String from, String to) {
    final edges = adjacency[from];
    if (edges == null) return null;
    for (final edge in edges) {
      if (edge.to == to) return edge;
    }
    return null;
  }
}

class OfflineGraphNode {
  final String id;
  final double lat;
  final double lng;

  OfflineGraphNode({
    required this.id,
    required this.lat,
    required this.lng,
  });

  factory OfflineGraphNode.fromJson(Map<String, dynamic> json) {
    return OfflineGraphNode(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class OfflineGraphEdge {
  final String from;
  final String to;
  final double weight;
  final bool oneWay;
  final List<LatLng>? shape;

  OfflineGraphEdge({
    required this.from,
    required this.to,
    required this.weight,
    required this.oneWay,
    required this.shape,
  });

  factory OfflineGraphEdge.fromJson(Map<String, dynamic> json) {
    final shape = (json['shape'] as List<dynamic>?)
        ?.map((point) => LatLng(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ))
        .toList();

    return OfflineGraphEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      weight: (json['weight'] as num).toDouble(),
      oneWay: json['oneWay'] as bool? ?? false,
      shape: shape,
    );
  }

  OfflineGraphEdge reversed() {
    return OfflineGraphEdge(
      from: to,
      to: from,
      weight: weight,
      oneWay: oneWay,
      shape: shape?.reversed.toList(),
    );
  }
}

class OfflineGraphMeta {
  final int version;
  final DateTime lastSync;

  OfflineGraphMeta({
    required this.version,
    required this.lastSync,
  });

  factory OfflineGraphMeta.fromJson(Map<String, dynamic> json) {
    return OfflineGraphMeta(
      version: json['version'] as int? ?? 0,
      lastSync: DateTime.parse(json['lastSync'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastSync': lastSync.toIso8601String(),
    };
  }
}

class _QueueItem {
  final String nodeId;
  final double cost;

  const _QueueItem(this.nodeId, this.cost);
}

class _PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;

  _PriorityQueue(this._comparator);

  void add(T item) {
    _items.add(item);
    _items.sort(_comparator);
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
}
