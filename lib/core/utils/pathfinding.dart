import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/pagoda_model.dart';
import 'helpers.dart';

typedef PathDistanceCalculator = double Function(Pagoda a, Pagoda b);

class PathSearchResult {
  final List<Pagoda> path;
  final double distanceKm;
  final List<String> roadNodePath;
  final bool isRoadGraphRoute;
  final bool requiresRiverCrossing;

  const PathSearchResult({
    required this.path,
    required this.distanceKm,
    this.roadNodePath = const [],
    this.isRoadGraphRoute = false,
    this.requiresRiverCrossing = false,
  });

  const PathSearchResult.empty()
    : path = const [],
      distanceKm = 0,
      roadNodePath = const [],
      isRoadGraphRoute = false,
      requiresRiverCrossing = false;

  const PathSearchResult.riverCrossing()
    : path = const [],
      distanceKm = 0,
      roadNodePath = const [],
      isRoadGraphRoute = false,
      requiresRiverCrossing = true;

  bool get isEmpty => path.isEmpty;
}

class PathfindingService {
  static const String _graphAssetPath = 'assets/data/pagoda_route_graph.json';
  static const double _improvementEpsilonKm = 0.0005;

  static PagodaRouteGraphData? _cachedGraph;

  static Future<PagodaRouteGraphData?> loadGraph() async {
    final cached = _cachedGraph;
    if (cached != null) {
      return cached;
    }

    try {
      final raw = await rootBundle.loadString(_graphAssetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final graph = PagodaRouteGraphData.fromJson(decoded);
      _cachedGraph = graph;
      return graph;
    } catch (_) {
      return null;
    }
  }

  static Future<PathSearchResult> findPath(
    Pagoda start,
    Pagoda goal,
    List<Pagoda> allPagodas, {
    bool requireTrustedRoadAccess = true,
  }) async {
    if (start.id == goal.id) {
      return PathSearchResult(path: [start], distanceKm: 0);
    }

    final graph = await loadGraph();
    if (graph == null) {
      return _buildDirectFallbackResult(start, goal);
    }

    final startNode = graph.nodes[start.id];
    final goalNode = graph.nodes[goal.id];
    if (startNode == null || goalNode == null) {
      return _buildDirectFallbackResult(start, goal);
    }
    if (startNode.requiresRiverCrossing || goalNode.requiresRiverCrossing) {
      return const PathSearchResult.riverCrossing();
    }

    // Pagodas far from the offline road graph cannot get honest turn-by-turn
    // polylines, but we still allow graph search for pagoda waypoint lists.
    const maxTrustedAccessGapKm = 0.5;
    if (requireTrustedRoadAccess &&
        (startNode.accessGapKm > maxTrustedAccessGapKm ||
            goalNode.accessGapKm > maxTrustedAccessGapKm)) {
      return _buildDirectFallbackResult(start, goal);
    }

    final pagodasById = <String, Pagoda>{
      for (final pagoda in allPagodas) pagoda.id: pagoda,
    };

    final gScores = <String, double>{start.id: 0};
    final previous = <String, String?>{};
    final openSet = PriorityQueue<_PathQueueItem>((a, b) {
      return a.fScore.compareTo(b.fScore);
    });

    openSet.add(
      _PathQueueItem(nodeId: start.id, fScore: _heuristic(start, goal)),
    );

    final closedSet = <String>{};

    while (openSet.isNotEmpty) {
      final currentItem = openSet.removeFirst();
      if (closedSet.contains(currentItem.nodeId)) {
        continue;
      }

      final currentPagoda = pagodasById[currentItem.nodeId];
      final currentG = gScores[currentItem.nodeId];
      if (currentPagoda == null || currentG == null) {
        continue;
      }

      final currentF = currentG + _heuristic(currentPagoda, goal);
      if (currentItem.fScore > currentF + _improvementEpsilonKm) {
        continue;
      }

      if (currentItem.nodeId == goal.id) {
        final path = _reconstructPath(
          startId: start.id,
          goalId: goal.id,
          previous: previous,
          pagodasById: pagodasById,
        );
        final roadNodePath = _roadNodePathForPagodaPath(path, graph);
        final hasTrustedRoadAccess = path.every(
          (pagoda) =>
              (graph.nodes[pagoda.id]?.accessGapKm ?? double.infinity) <=
              maxTrustedAccessGapKm,
        );
        return PathSearchResult(
          path: path,
          distanceKm: currentG,
          roadNodePath: roadNodePath,
          isRoadGraphRoute: hasTrustedRoadAccess && roadNodePath.length >= 2,
        );
      }

      closedSet.add(currentItem.nodeId);

      final neighbors = graph.adjacency[currentItem.nodeId] ?? const [];
      for (final edge in neighbors) {
        if (closedSet.contains(edge.to)) {
          continue;
        }

        final neighborPagoda = pagodasById[edge.to];
        if (neighborPagoda == null) {
          continue;
        }

        final tentativeG = currentG + edge.weight;
        if (tentativeG < (gScores[edge.to] ?? double.infinity)) {
          gScores[edge.to] = tentativeG;
          previous[edge.to] = currentItem.nodeId;

          final fScore = tentativeG + _heuristic(neighborPagoda, goal);
          openSet.add(_PathQueueItem(nodeId: edge.to, fScore: fScore));
        }
      }
    }

    return _buildDirectFallbackResult(start, goal);
  }

  static double calculatePathDistance(
    List<Pagoda> path, {
    PathDistanceCalculator? distanceCalculator,
  }) {
    if (path.length < 2) {
      return 0;
    }

    final distance = distanceCalculator ?? _haversineDistance;
    var totalDistance = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      totalDistance += distance(path[i], path[i + 1]);
    }
    return totalDistance;
  }

  static bool requiresRiverCrossingBetween(
    String startId,
    String goalId,
    PagodaRouteGraphData? graph,
  ) {
    if (startId == goalId || graph == null) {
      return false;
    }
    return (graph.nodes[startId]?.requiresRiverCrossing ?? false) ||
        (graph.nodes[goalId]?.requiresRiverCrossing ?? false);
  }

  static bool routeRequiresRiverCrossing(
    Iterable<String> pagodaIds,
    PagodaRouteGraphData? graph,
  ) {
    final ids = pagodaIds.where((id) => id.isNotEmpty).toSet();
    if (ids.length < 2 || graph == null) {
      return false;
    }
    return ids.any((id) => graph.nodes[id]?.requiresRiverCrossing ?? false);
  }

  static List<Pagoda> optimizeRouteOrder(
    List<Pagoda> pagodas, {
    bool keepFirst = true,
    int maxIterations = 200,
    PathDistanceCalculator? distanceCalculator,
  }) {
    if (pagodas.length <= 2) return pagodas;

    final distance = distanceCalculator ?? _haversineDistance;

    final initial = keepFirst
        ? _nearestNeighborOrder(pagodas.first, pagodas, distance: distance)
        : _nearestNeighborOrder(
            _chooseStartForFreeRoute(pagodas),
            pagodas,
            distance: distance,
          );

    final optimized = List<Pagoda>.from(initial);
    final n = optimized.length;
    final startIdx = keepFirst ? 1 : 0;
    var iterations = 0;
    var improved = true;

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations += 1;
      for (var i = startIdx; i < n - 1; i++) {
        for (var k = i + 1; k < n; k++) {
          final delta = _twoOptDelta(optimized, i, k, distance);
          if (delta < -_improvementEpsilonKm) {
            _reverseSegment(optimized, i, k);
            improved = true;
          }
        }
      }
    }

    return optimized;
  }

  static double _heuristic(Pagoda from, Pagoda goal) {
    return Helpers.calculateDistance(
      from.latitude,
      from.longitude,
      goal.latitude,
      goal.longitude,
    );
  }

  static List<Pagoda> _reconstructPath({
    required String startId,
    required String goalId,
    required Map<String, String?> previous,
    required Map<String, Pagoda> pagodasById,
  }) {
    final path = <Pagoda>[];
    String? currentId = goalId;

    while (currentId != null) {
      final pagoda = pagodasById[currentId];
      if (pagoda == null) {
        return [];
      }
      path.insert(0, pagoda);
      if (currentId == startId) {
        break;
      }
      currentId = previous[currentId];
    }

    if (path.isEmpty || path.first.id != startId) {
      return [];
    }

    return path;
  }

  static List<String> _roadNodePathForPagodaPath(
    List<Pagoda> path,
    PagodaRouteGraphData graph,
  ) {
    final roadNodePath = <String>[];
    for (final pagoda in path) {
      final roadNodeId = graph.nodes[pagoda.id]?.roadNodeId;
      if (roadNodeId == null || roadNodeId.isEmpty) {
        continue;
      }
      if (roadNodePath.isEmpty || roadNodePath.last != roadNodeId) {
        roadNodePath.add(roadNodeId);
      }
    }
    return roadNodePath;
  }

  static List<Pagoda> _nearestNeighborOrder(
    Pagoda start,
    List<Pagoda> candidates, {
    required PathDistanceCalculator distance,
  }) {
    final ordered = <Pagoda>[start];
    final pool = candidates.where((pagoda) => pagoda.id != start.id).toList();

    while (pool.isNotEmpty) {
      final current = ordered.last;
      var minDistance = double.infinity;
      Pagoda? nearest;
      for (final pagoda in pool) {
        final currentDistance = distance(current, pagoda);
        if (currentDistance < minDistance) {
          minDistance = currentDistance;
          nearest = pagoda;
        }
      }
      if (nearest == null) {
        break;
      }
      ordered.add(nearest);
      pool.remove(nearest);
    }

    return ordered;
  }

  static Pagoda _chooseStartForFreeRoute(List<Pagoda> pagodas) {
    if (pagodas.length <= 1) {
      return pagodas.first;
    }

    final centroidLat =
        pagodas.fold<double>(0, (sum, pagoda) => sum + pagoda.latitude) /
        pagodas.length;
    final centroidLon =
        pagodas.fold<double>(0, (sum, pagoda) => sum + pagoda.longitude) /
        pagodas.length;

    Pagoda best = pagodas.first;
    var bestDistance = double.infinity;
    for (final pagoda in pagodas) {
      final centroidDistance = Helpers.calculateDistance(
        pagoda.latitude,
        pagoda.longitude,
        centroidLat,
        centroidLon,
      );
      if (centroidDistance < bestDistance) {
        bestDistance = centroidDistance;
        best = pagoda;
      }
    }

    return best;
  }

  static double _twoOptDelta(
    List<Pagoda> route,
    int i,
    int k,
    PathDistanceCalculator distance,
  ) {
    final b = route[i];
    final c = route[k];
    final Pagoda? a = i > 0 ? route[i - 1] : null;
    final Pagoda? d = k + 1 < route.length ? route[k + 1] : null;

    var oldDistance = 0.0;
    var newDistance = 0.0;

    if (a != null) {
      oldDistance += distance(a, b);
      newDistance += distance(a, c);
    }
    if (d != null) {
      oldDistance += distance(c, d);
      newDistance += distance(b, d);
    }

    return newDistance - oldDistance;
  }

  static void _reverseSegment(List<Pagoda> route, int i, int k) {
    while (i < k) {
      final temp = route[i];
      route[i] = route[k];
      route[k] = temp;
      i++;
      k--;
    }
  }

  static double _haversineDistance(Pagoda a, Pagoda b) {
    return Helpers.calculateDistance(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  static PathSearchResult _buildDirectFallbackResult(
    Pagoda start,
    Pagoda goal,
  ) {
    return PathSearchResult(
      path: [start, goal],
      distanceKm: _haversineDistance(start, goal),
      roadNodePath: const [],
    );
  }
}

class PagodaRouteGraphData {
  final int version;
  final Map<String, PagodaRouteGraphNode> nodes;
  final Map<String, List<PagodaRouteGraphEdge>> adjacency;

  PagodaRouteGraphData({
    required this.version,
    required this.nodes,
    required this.adjacency,
  });

  factory PagodaRouteGraphData.fromJson(Map<String, dynamic> json) {
    final nodeList = (json['nodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(PagodaRouteGraphNode.fromJson)
        .toList();
    final nodes = {for (final node in nodeList) node.pagodaId: node};

    final edgeList = (json['edges'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(PagodaRouteGraphEdge.fromJson)
        .toList();

    final adjacency = <String, List<PagodaRouteGraphEdge>>{};
    for (final edge in edgeList) {
      adjacency.putIfAbsent(edge.from, () => []).add(edge);
      if (!edge.oneWay) {
        adjacency.putIfAbsent(edge.to, () => []).add(edge.reversed());
      }
    }

    return PagodaRouteGraphData(
      version: json['version'] as int? ?? 0,
      nodes: nodes,
      adjacency: adjacency,
    );
  }
}

class PagodaRouteGraphNode {
  final String pagodaId;
  final String roadNodeId;
  final double lat;
  final double lng;
  final double accessGapKm;
  final bool requiresRiverCrossing;

  const PagodaRouteGraphNode({
    required this.pagodaId,
    required this.roadNodeId,
    required this.lat,
    required this.lng,
    required this.accessGapKm,
    this.requiresRiverCrossing = false,
  });

  factory PagodaRouteGraphNode.fromJson(Map<String, dynamic> json) {
    return PagodaRouteGraphNode(
      pagodaId: json['pagodaId'] as String,
      roadNodeId: json['roadNodeId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accessGapKm: (json['accessGapKm'] as num).toDouble(),
      requiresRiverCrossing: json['requiresRiverCrossing'] as bool? ?? false,
    );
  }
}

class PagodaRouteGraphEdge {
  final String from;
  final String to;
  final double weight;
  final double roadDistanceKm;
  final bool oneWay;

  const PagodaRouteGraphEdge({
    required this.from,
    required this.to,
    required this.weight,
    required this.roadDistanceKm,
    required this.oneWay,
  });

  factory PagodaRouteGraphEdge.fromJson(Map<String, dynamic> json) {
    return PagodaRouteGraphEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      weight: (json['weight'] as num).toDouble(),
      roadDistanceKm: (json['roadDistanceKm'] as num).toDouble(),
      oneWay: json['oneWay'] as bool? ?? false,
    );
  }

  PagodaRouteGraphEdge reversed() {
    return PagodaRouteGraphEdge(
      from: to,
      to: from,
      weight: weight,
      roadDistanceKm: roadDistanceKm,
      oneWay: oneWay,
    );
  }
}

class _PathQueueItem {
  final String nodeId;
  final double fScore;

  const _PathQueueItem({required this.nodeId, required this.fScore});
}

class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  void add(T item) {
    _items.add(item);
    _siftUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }
    return first;
  }

  bool get isNotEmpty => _items.isNotEmpty;

  void _siftUp(int index) {
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (_comparator(_items[index], _items[parent]) >= 0) break;
      _swap(index, parent);
      index = parent;
    }
  }

  void _siftDown(int index) {
    final length = _items.length;
    while (true) {
      var smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;
      if (left < length && _comparator(_items[left], _items[smallest]) < 0) {
        smallest = left;
      }
      if (right < length && _comparator(_items[right], _items[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int a, int b) {
    final temp = _items[a];
    _items[a] = _items[b];
    _items[b] = temp;
  }
}
