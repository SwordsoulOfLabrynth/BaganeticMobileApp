import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/pagoda_model.dart';
import '../utils/helpers.dart';
import 'offline_route_service.dart';

enum RouteSegmentMode { road, ferry }

enum MultimodalPathStepKind { pagoda, ferryTerminal }

/// Ordered stop shown in Find Path / itinerary UI.
/// Ferry terminals are transfer points, not pagoda graph nodes.
class MultimodalPathStep {
  const MultimodalPathStep({
    required this.id,
    required this.name,
    required this.nameMyanmar,
    required this.location,
    required this.kind,
    this.pagoda,
  });

  final String id;
  final String name;
  final String nameMyanmar;
  final LatLng location;
  final MultimodalPathStepKind kind;
  final Pagoda? pagoda;

  bool get isFerryTerminal => kind == MultimodalPathStepKind.ferryTerminal;

  factory MultimodalPathStep.fromPagoda(Pagoda pagoda) {
    return MultimodalPathStep(
      id: pagoda.id,
      name: pagoda.name,
      nameMyanmar: pagoda.nameMyanmar ?? pagoda.name,
      location: LatLng(pagoda.latitude, pagoda.longitude),
      kind: MultimodalPathStepKind.pagoda,
      pagoda: pagoda,
    );
  }

  factory MultimodalPathStep.fromTerminal({
    required String id,
    required FerryTerminal terminal,
  }) {
    return MultimodalPathStep(
      id: id,
      name: terminal.name,
      nameMyanmar: terminal.nameMyanmar,
      location: terminal.location,
      kind: MultimodalPathStepKind.ferryTerminal,
    );
  }
}

class RouteEndpoint {
  const RouteEndpoint({required this.location, this.pagodaId});

  final LatLng location;
  final String? pagodaId;
}

class MultimodalRouteSegment {
  const MultimodalRouteSegment({
    required this.mode,
    required this.points,
    this.isFallback = false,
  });

  final RouteSegmentMode mode;
  final List<LatLng> points;
  final bool isFallback;
}

class MultimodalRoutePlan {
  const MultimodalRoutePlan(this.segments);

  final List<MultimodalRouteSegment> segments;

  bool get hasFerry =>
      segments.any((segment) => segment.mode == RouteSegmentMode.ferry);

  bool get usesFallback => segments.any((segment) => segment.isFallback);

  List<LatLng> get points {
    final route = <LatLng>[];
    for (final segment in segments) {
      if (segment.points.isEmpty) {
        continue;
      }
      if (route.isNotEmpty && route.last == segment.points.first) {
        route.addAll(segment.points.skip(1));
      } else {
        route.addAll(segment.points);
      }
    }
    return route;
  }

  double get distanceKm {
    var total = 0.0;
    for (final segment in segments) {
      for (var index = 0; index < segment.points.length - 1; index++) {
        final from = segment.points[index];
        final to = segment.points[index + 1];
        total += Helpers.calculateDistance(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        );
      }
    }
    return total;
  }
}

class FerryTerminal {
  const FerryTerminal({
    required this.name,
    required this.nameMyanmar,
    required this.location,
  });

  final String name;
  final String nameMyanmar;
  final LatLng location;

  factory FerryTerminal.fromJson(Map<String, dynamic> json) {
    return FerryTerminal(
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String? ?? json['name'] as String,
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    );
  }
}

class FerryConnection {
  const FerryConnection({
    required this.id,
    required this.pagodaId,
    this.mainlandPagodaId,
    required this.originTerminal,
    required this.destinationTerminal,
    required this.ferryRouteGeometry,
    required this.availabilityNote,
    required this.availabilityNoteMyanmar,
  });

  final String id;
  final String pagodaId;

  /// Mainland-side pagoda nearest the origin terminal (e.g. Bu Paya).
  /// Used to run A* on the Bagan-side road graph before/after the ferry.
  final String? mainlandPagodaId;
  final FerryTerminal originTerminal;
  final FerryTerminal destinationTerminal;
  final List<LatLng> ferryRouteGeometry;
  final String availabilityNote;
  final String availabilityNoteMyanmar;

  /// Curated from the mapped OSM ferry way. It is the best available
  /// geographical route line, but still not a live vessel position feed.
  List<LatLng> get ferryPoints => ferryRouteGeometry.isNotEmpty
      ? ferryRouteGeometry
      : [originTerminal.location, destinationTerminal.location];

  factory FerryConnection.fromJson(Map<String, dynamic> json) {
    return FerryConnection(
      id: json['id'] as String,
      pagodaId: json['pagodaId'] as String,
      mainlandPagodaId: json['mainlandPagodaId'] as String?,
      originTerminal: FerryTerminal.fromJson(
        json['originTerminal'] as Map<String, dynamic>,
      ),
      destinationTerminal: FerryTerminal.fromJson(
        json['destinationTerminal'] as Map<String, dynamic>,
      ),
      ferryRouteGeometry:
          (json['ferryRouteGeometry'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()
              .map(
                (point) => LatLng(
                  (point['latitude'] as num).toDouble(),
                  (point['longitude'] as num).toDouble(),
                ),
              )
              .toList(growable: false),
      availabilityNote: json['availabilityNote'] as String,
      availabilityNoteMyanmar: json['availabilityNoteMyanmar'] as String,
    );
  }
}

class MultimodalRouteService {
  MultimodalRouteService._();

  static final instance = MultimodalRouteService._();
  static const _assetPath = 'assets/data/multimodal_routes.json';

  List<FerryConnection>? _cachedConnections;

  Future<List<FerryConnection>> loadFerryConnections() async {
    final cached = _cachedConnections;
    if (cached != null) {
      return cached;
    }

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final connections =
          (data['ferryConnections'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()
              .map(FerryConnection.fromJson)
              .toList(growable: false);
      _cachedConnections = connections;
      return connections;
    } catch (_) {
      return const [];
    }
  }

  Future<FerryConnection?> connectionForPagoda(String? pagodaId) async {
    if (pagodaId == null || pagodaId.isEmpty) {
      return null;
    }
    final connections = await loadFerryConnections();
    for (final connection in connections) {
      if (connection.pagodaId == pagodaId) {
        return connection;
      }
    }
    return null;
  }

  Future<bool> routeUsesFerry(Iterable<String> pagodaIds) async {
    final ids = pagodaIds.where((id) => id.isNotEmpty).toSet();
    if (ids.length < 2) {
      return false;
    }
    final connections = await loadFerryConnections();
    return connections.any((connection) => ids.contains(connection.pagodaId));
  }

  Future<MultimodalRoutePlan> buildPlan(
    RouteEndpoint start,
    RouteEndpoint end, {
    List<Pagoda> mainlandPagodaPath = const [],
    List<String> mainlandRoadNodePath = const [],
  }) async {
    final connection =
        await connectionForPagoda(start.pagodaId) ??
        await connectionForPagoda(end.pagodaId);
    if (connection == null || start.pagodaId == end.pagodaId) {
      return MultimodalRoutePlan([
        await _buildRoadSegment(start.location, end.location),
      ]);
    }

    final startsAtFerryPagoda = start.pagodaId == connection.pagodaId;
    final mainlandTerminal = connection.originTerminal;
    final tantKyiTerminal = connection.destinationTerminal;
    final ferryPoints = connection.ferryPoints;
    final segments = <MultimodalRouteSegment>[];

    if (startsAtFerryPagoda) {
      segments.add(
        await _buildRoadSegment(start.location, tantKyiTerminal.location),
      );
      segments.add(
        MultimodalRouteSegment(
          mode: RouteSegmentMode.ferry,
          points: ferryPoints.reversed.toList(growable: false),
        ),
      );
      segments.add(
        await _buildRoadSegmentForRoadNodes(
          mainlandRoadNodePath,
          fallbackPoints: _mainlandFallbackPoints(
            pagodaPath: mainlandPagodaPath,
            start: mainlandTerminal.location,
            end: end.location,
          ),
        ),
      );
    } else {
      segments.add(
        await _buildRoadSegmentForRoadNodes(
          mainlandRoadNodePath,
          fallbackPoints: _mainlandFallbackPoints(
            pagodaPath: mainlandPagodaPath,
            start: start.location,
            end: mainlandTerminal.location,
          ),
        ),
      );
      segments.add(
        MultimodalRouteSegment(
          mode: RouteSegmentMode.ferry,
          points: ferryPoints,
        ),
      );
      segments.add(
        await _buildRoadSegment(tantKyiTerminal.location, end.location),
      );
    }

    return MultimodalRoutePlan(
      segments.where((segment) => segment.points.length >= 2).toList(),
    );
  }

  Future<MultimodalRoutePlan> buildTripPlan(List<RouteEndpoint> stops) async {
    if (stops.length < 2) {
      return const MultimodalRoutePlan([]);
    }

    final segments = <MultimodalRouteSegment>[];
    for (var index = 0; index < stops.length - 1; index++) {
      final leg = await buildPlan(stops[index], stops[index + 1]);
      segments.addAll(leg.segments);
    }
    return MultimodalRoutePlan(segments);
  }

  Future<MultimodalRouteSegment> _buildRoadSegment(
    LatLng start,
    LatLng end,
  ) async {
    final route = await OfflineRouteService.instance.buildRouteForPoints([
      start,
      end,
    ]);
    return MultimodalRouteSegment(
      mode: RouteSegmentMode.road,
      points: route.isEmpty ? [start, end] : route,
      isFallback: route.isEmpty,
    );
  }

  Future<MultimodalRouteSegment> _buildRoadSegmentForRoadNodes(
    List<String> roadNodeIds, {
    required List<LatLng> fallbackPoints,
  }) async {
    final route = roadNodeIds.length >= 2
        ? await OfflineRouteService.instance.buildRouteForRoadNodeIds(
            roadNodeIds,
            fallbackPoints: fallbackPoints,
          )
        : await OfflineRouteService.instance.buildRouteForPoints(
            fallbackPoints,
          );
    return MultimodalRouteSegment(
      mode: RouteSegmentMode.road,
      points: route.isEmpty ? fallbackPoints : route,
      isFallback: route.isEmpty,
    );
  }

  List<LatLng> _mainlandFallbackPoints({
    required List<Pagoda> pagodaPath,
    required LatLng start,
    required LatLng end,
  }) {
    final points = <LatLng>[start];
    for (final pagoda in pagodaPath) {
      final point = LatLng(pagoda.latitude, pagoda.longitude);
      if (points.last != point) {
        points.add(point);
      }
    }
    if (points.last != end) {
      points.add(end);
    }
    return points;
  }

  /// Builds the ordered Find Path stop list for a ferry journey.
  ///
  /// [mainlandPath] should be the A* pagoda path on the Bagan side
  /// (start→gateway or gateway→end). Ferry terminals are inserted as
  /// transfer waypoints so the UI is not collapsed to start+end only.
  static List<MultimodalPathStep> buildFerryPathSteps({
    required Pagoda start,
    required Pagoda end,
    required FerryConnection connection,
    List<Pagoda> mainlandPath = const [],
  }) {
    final startsAtFerryPagoda = start.id == connection.pagodaId;
    final steps = <MultimodalPathStep>[];
    final seen = <String>{};

    void addPagoda(Pagoda pagoda) {
      if (!seen.add(pagoda.id)) return;
      steps.add(MultimodalPathStep.fromPagoda(pagoda));
    }

    void addTerminal(String suffix, FerryTerminal terminal) {
      final id = '${connection.id}-$suffix';
      if (!seen.add(id)) return;
      steps.add(MultimodalPathStep.fromTerminal(id: id, terminal: terminal));
    }

    if (startsAtFerryPagoda) {
      addPagoda(start);
      addTerminal('west', connection.destinationTerminal);
      addTerminal('east', connection.originTerminal);
      for (final pagoda in mainlandPath) {
        addPagoda(pagoda);
      }
      addPagoda(end);
    } else {
      for (final pagoda in mainlandPath) {
        addPagoda(pagoda);
      }
      if (steps.isEmpty) {
        addPagoda(start);
      }
      addTerminal('east', connection.originTerminal);
      addTerminal('west', connection.destinationTerminal);
      addPagoda(end);
    }

    return steps;
  }

  static List<MultimodalPathStep> stepsFromPagodas(List<Pagoda> path) {
    return path.map(MultimodalPathStep.fromPagoda).toList(growable: false);
  }
}
