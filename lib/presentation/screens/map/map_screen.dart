import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/multimodal_route_service.dart';
import '../../../core/services/offline_route_service.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/pathfinding.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sign_in_required_view.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../trips/create_trip_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../../../core/localization/app_localizations.dart';

enum MapTripMode { browse, path, trips }

class MapScreen extends StatefulWidget {
  final Pagoda? initialPagoda;
  final MapTripMode initialMode;

  const MapScreen({
    super.key,
    this.initialPagoda,
    this.initialMode = MapTripMode.browse,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Pagoda? _selectedPagoda;
  Trip? _selectedTrip;
  List<LatLng> _tripRoute = [];
  bool _isTripRouteLoading = false;
  bool _isTripRouteFallback = false;
  List<MultimodalRouteSegment> _tripRouteSegments = [];
  bool _tripRouteUsesFerry = false;
  Pagoda? _pathStartPagoda;
  Pagoda? _pathEndPagoda;
  List<Pagoda> _shortestPathPagodas = [];
  List<MultimodalPathStep> _shortestPathSteps = [];
  double _shortestPathDistanceKm = 0;
  List<LatLng> _shortestPathRoute = [];
  List<MultimodalRouteSegment> _shortestPathRouteSegments = [];
  bool _shortestPathUsesFerry = false;
  bool _isPathRouteLoading = false;
  bool _isPathRouteFallback = false;
  bool _hasAttemptedPathSearch = false;
  late MapTripMode _mode;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    if (widget.initialPagoda != null) {
      _selectedPagoda = widget.initialPagoda;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(
            widget.initialPagoda!.latitude,
            widget.initialPagoda!.longitude,
          ),
          AppConstants.defaultZoom + 2,
        );
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _setMode(MapTripMode mode) async {
    if (mode == MapTripMode.trips) {
      final canContinue = await AuthGate.ensureSignedIn(
        context,
        featureName: context.l10n.translate('map.planTrip'),
      );
      if (!canContinue || !mounted) {
        return;
      }
    }
    if (_mode == mode) return;
    final selectedTrip = _selectedTrip;
    final shouldClearSelectedPagoda =
        mode == MapTripMode.path ||
        (mode == MapTripMode.trips &&
            selectedTrip != null &&
            !selectedTrip.stops.any(
              (stop) => stop.pagodaId == _selectedPagoda?.id,
            ));
    setState(() {
      _mode = mode;
      if (shouldClearSelectedPagoda) {
        _selectedPagoda = null;
      }
    });
    if (_mode == MapTripMode.trips && _selectedTrip != null) {
      _loadTripRoute(_selectedTrip!);
    }
    if (_mode == MapTripMode.path && _shortestPathRoute.isNotEmpty) {
      _focusRoute(_shortestPathRoute);
    }
  }

  Future<void> _loadTripRoute(Trip trip) async {
    final points = trip.stops
        .map((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();
    if (points.isEmpty) {
      setState(() {
        _tripRoute = [];
        _isTripRouteFallback = false;
        _tripRouteSegments = [];
        _tripRouteUsesFerry = false;
        _isTripRouteLoading = false;
      });
      return;
    }

    setState(() {
      _tripRoute = points;
      _isTripRouteFallback = false;
      _tripRouteSegments = [];
      _tripRouteUsesFerry = false;
      _isTripRouteLoading = true;
    });

    final usesFerry = await MultimodalRouteService.instance.routeUsesFerry(
      trip.stops.map((stop) => stop.pagodaId),
    );
    if (!mounted || _selectedTrip?.id != trip.id) {
      return;
    }
    if (usesFerry) {
      final plan = await MultimodalRouteService.instance.buildTripPlan(
        trip.stops
            .map(
              (stop) => RouteEndpoint(
                pagodaId: stop.pagodaId,
                location: LatLng(stop.latitude, stop.longitude),
              ),
            )
            .toList(growable: false),
      );
      if (!mounted || _selectedTrip?.id != trip.id) {
        return;
      }
      setState(() {
        _tripRoute = plan.points;
        _isTripRouteFallback = plan.usesFallback;
        _tripRouteSegments = plan.segments;
        _tripRouteUsesFerry = plan.hasFerry;
        _isTripRouteLoading = false;
      });
      _focusRoute(plan.points);
      return;
    }

    final route = await OfflineRouteService.instance.buildRouteForPoints(
      points,
    );
    if (!mounted) return;

    final resolved = route.isEmpty ? points : route;
    setState(() {
      _tripRoute = resolved;
      _isTripRouteFallback = route.isEmpty;
      _tripRouteSegments = [];
      _tripRouteUsesFerry = false;
      _isTripRouteLoading = false;
    });
    _focusRoute(resolved);
  }

  void _focusRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, AppConstants.defaultZoom + 2);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  List<Polyline> _buildSegmentPolylines(
    List<MultimodalRouteSegment> segments, {
    Color roadColor = const Color(0xFFD4AF37),
  }) {
    return segments
        .where((segment) => segment.points.length >= 2)
        .map((segment) {
          final isFerry = segment.mode == RouteSegmentMode.ferry;
          return Polyline(
            points: segment.points,
            color: isFerry ? const Color(0xFF2196C4) : roadColor,
            // A ferry is a transfer between terminals, not a road or a
            // tracked boat navigation line. Keep it visually distinct from
            // the road route so it cannot be mistaken for turn-by-turn data.
            strokeWidth: isFerry ? 5 : 5,
            borderStrokeWidth: 3,
            borderColor: isFerry
                ? const Color(0xFF0F4C65).withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.25),
            pattern: isFerry
                ? StrokePattern.dashed(
                    segments: [14.0, 10.0],
                    patternFit: PatternFit.appendDot,
                  )
                : const StrokePattern.solid(),
          );
        })
        .toList(growable: false);
  }

  List<Marker> _buildFerryMarkers(List<MultimodalRouteSegment> segments) {
    final seenTerminals = <String>{};
    final markers = <Marker>[];

    for (final segment in segments.where(
      (segment) =>
          segment.mode == RouteSegmentMode.ferry && segment.points.length >= 2,
    )) {
      for (final terminal in [segment.points.first, segment.points.last]) {
        final key = '${terminal.latitude},${terminal.longitude}';
        if (!seenTerminals.add(key)) continue;

        markers.add(
          Marker(
            point: terminal,
            width: 32,
            height: 32,
            child: Tooltip(
              message: context.l10n.translate('route.ferryTerminal'),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF166B91),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_boat_filled_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _selectTrip(Trip trip) {
    if (_selectedTrip?.id == trip.id) return;
    final containsSelectedPagoda = trip.stops.any(
      (stop) => stop.pagodaId == _selectedPagoda?.id,
    );
    setState(() {
      _selectedTrip = trip;
      if (!containsSelectedPagoda) {
        _selectedPagoda = null;
      }
    });
    _loadTripRoute(trip);
  }

  void _clearPathSelection() {
    setState(() {
      _pathStartPagoda = null;
      _pathEndPagoda = null;
      _shortestPathPagodas = [];
      _shortestPathSteps = [];
      _shortestPathDistanceKm = 0;
      _shortestPathRoute = [];
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _isPathRouteLoading = false;
      _isPathRouteFallback = false;
      _hasAttemptedPathSearch = false;
    });
  }

  void _focusPagoda(Pagoda pagoda) {
    _mapController.move(
      LatLng(pagoda.latitude, pagoda.longitude),
      AppConstants.defaultZoom + 2,
    );
  }

  void _selectPagoda(Pagoda pagoda) {
    setState(() {
      _selectedPagoda = pagoda;
    });
    _focusPagoda(pagoda);
  }

  void _handleTripStopTap(TripStop stop, List<Pagoda> pagodas) {
    final pagoda = _resolveTripStopPagoda(stop, pagodas);
    if (pagoda == null) {
      return;
    }
    _selectPagoda(pagoda);
  }

  Pagoda? _resolveTripStopPagoda(TripStop stop, List<Pagoda> pagodas) {
    for (final pagoda in pagodas) {
      if (pagoda.id == stop.pagodaId) {
        return pagoda;
      }
    }
    return null;
  }

  void _setPathStart(Pagoda? pagoda) {
    if (pagoda != null && _pathEndPagoda?.id == pagoda.id) {
      Helpers.showSnackBar(
        context,
        context.l10n.translate('map.pathSelectDifferent'),
        isError: true,
      );
      return;
    }

    setState(() {
      _pathStartPagoda = pagoda;
      _shortestPathPagodas = [];
      _shortestPathSteps = [];
      _shortestPathDistanceKm = 0;
      _shortestPathRoute = [];
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _isPathRouteLoading = false;
      _isPathRouteFallback = false;
      _hasAttemptedPathSearch = false;
    });

    if (pagoda != null) {
      _focusPagoda(pagoda);
    }
  }

  void _setPathEnd(Pagoda? pagoda) {
    if (pagoda != null && _pathStartPagoda?.id == pagoda.id) {
      Helpers.showSnackBar(
        context,
        context.l10n.translate('map.pathSelectDifferent'),
        isError: true,
      );
      return;
    }

    setState(() {
      _pathEndPagoda = pagoda;
      _shortestPathPagodas = [];
      _shortestPathSteps = [];
      _shortestPathDistanceKm = 0;
      _shortestPathRoute = [];
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _isPathRouteLoading = false;
      _isPathRouteFallback = false;
      _hasAttemptedPathSearch = false;
    });

    if (pagoda != null) {
      _focusPagoda(pagoda);
    }
  }

  Future<void> _swapPathEndpoints(List<Pagoda> allPagodas) async {
    final start = _pathStartPagoda;
    final end = _pathEndPagoda;
    if (start == null || end == null) {
      return;
    }

    setState(() {
      _pathStartPagoda = end;
      _pathEndPagoda = start;
    });
    await _loadShortestPath(allPagodas);
  }

  void _handlePathPagodaTap(Pagoda pagoda) {
    if (_pathStartPagoda == null || _pathEndPagoda != null) {
      setState(() {
        _pathStartPagoda = pagoda;
        _pathEndPagoda = null;
        _shortestPathPagodas = [];
        _shortestPathSteps = [];
        _shortestPathDistanceKm = 0;
        _shortestPathRoute = [];
        _shortestPathRouteSegments = [];
        _shortestPathUsesFerry = false;
        _isPathRouteLoading = false;
        _isPathRouteFallback = false;
        _hasAttemptedPathSearch = false;
      });
      _focusPagoda(pagoda);
      return;
    }

    if (_pathStartPagoda?.id == pagoda.id) {
      Helpers.showSnackBar(
        context,
        context.l10n.translate('map.pathSelectDifferent'),
        isError: true,
      );
      return;
    }

    setState(() {
      _pathEndPagoda = pagoda;
      _shortestPathPagodas = [];
      _shortestPathSteps = [];
      _shortestPathDistanceKm = 0;
      _shortestPathRoute = [];
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _isPathRouteLoading = false;
      _isPathRouteFallback = false;
      _hasAttemptedPathSearch = false;
    });
    _focusPagoda(pagoda);
  }

  Future<void> _loadShortestPath(List<Pagoda> allPagodas) async {
    final start = _pathStartPagoda;
    final end = _pathEndPagoda;
    if (start == null || end == null) {
      return;
    }

    setState(() {
      _isPathRouteLoading = true;
      _isPathRouteFallback = false;
      _shortestPathPagodas = [];
      _shortestPathSteps = [];
      _shortestPathDistanceKm = 0;
      _shortestPathRoute = [];
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _hasAttemptedPathSearch = true;
    });

    final result = await PathfindingService.findPath(start, end, allPagodas);
    if (result.requiresRiverCrossing) {
      final connection =
          await MultimodalRouteService.instance.connectionForPagoda(start.id) ??
          await MultimodalRouteService.instance.connectionForPagoda(end.id);
      final mainlandResult = connection == null
          ? const PathSearchResult.empty()
          : await _mainlandPathForFerry(
              start: start,
              end: end,
              connection: connection,
              allPagodas: allPagodas,
            );
      if (!mounted ||
          _pathStartPagoda?.id != start.id ||
          _pathEndPagoda?.id != end.id) {
        return;
      }

      final plan = await MultimodalRouteService.instance.buildPlan(
        RouteEndpoint(
          pagodaId: start.id,
          location: LatLng(start.latitude, start.longitude),
        ),
        RouteEndpoint(
          pagodaId: end.id,
          location: LatLng(end.latitude, end.longitude),
        ),
        mainlandPagodaPath: mainlandResult.path,
        mainlandRoadNodePath: mainlandResult.roadNodePath,
      );
      if (!mounted ||
          _pathStartPagoda?.id != start.id ||
          _pathEndPagoda?.id != end.id) {
        return;
      }
      if (!plan.hasFerry || plan.points.length < 2) {
        setState(() {
          _isPathRouteLoading = false;
        });
        Helpers.showSnackBar(
          context,
          context.l10n.translate('trip.noRouteFound'),
          isError: true,
        );
        return;
      }

      final steps = connection == null
          ? MultimodalRouteService.stepsFromPagodas([start, end])
          : MultimodalRouteService.buildFerryPathSteps(
              start: start,
              end: end,
              connection: connection,
              mainlandPath: mainlandResult.path,
            );
      final pathPagodas = steps
          .map((step) => step.pagoda)
          .whereType<Pagoda>()
          .toList(growable: false);

      setState(() {
        _shortestPathPagodas = pathPagodas;
        _shortestPathSteps = steps;
        _shortestPathDistanceKm = plan.distanceKm;
        _shortestPathRoute = plan.points;
        _shortestPathRouteSegments = plan.segments;
        _shortestPathUsesFerry = true;
        _isPathRouteFallback = plan.usesFallback;
        _isPathRouteLoading = false;
      });
      _focusRoute(plan.points);
      return;
    }
    if (result.isEmpty) {
      if (!mounted ||
          _pathStartPagoda?.id != start.id ||
          _pathEndPagoda?.id != end.id) {
        return;
      }

      setState(() {
        _isPathRouteLoading = false;
      });
      Helpers.showSnackBar(
        context,
        context.l10n.translate(
          result.requiresRiverCrossing
              ? 'route.riverCrossingRequired'
              : 'trip.noRouteFound',
        ),
        isError: true,
      );
      return;
    }

    final points = result.path
        .map((pagoda) => LatLng(pagoda.latitude, pagoda.longitude))
        .toList();
    final route = result.isRoadGraphRoute && result.roadNodePath.length >= 2
        ? await OfflineRouteService.instance.buildRouteForRoadNodeIds(
            result.roadNodePath,
            fallbackPoints: points,
          )
        : await OfflineRouteService.instance.buildRouteForPoints(points);
    if (!mounted ||
        _pathStartPagoda?.id != start.id ||
        _pathEndPagoda?.id != end.id) {
      return;
    }

    final resolved = route.isEmpty ? points : route;
    setState(() {
      _shortestPathPagodas = result.path;
      _shortestPathSteps = MultimodalRouteService.stepsFromPagodas(result.path);
      _shortestPathDistanceKm = result.distanceKm;
      _shortestPathRoute = resolved;
      _shortestPathRouteSegments = [];
      _shortestPathUsesFerry = false;
      _isPathRouteFallback = !result.isRoadGraphRoute || route.isEmpty;
      _isPathRouteLoading = false;
    });
    _focusRoute(resolved);
  }

  Future<PathSearchResult> _mainlandPathForFerry({
    required Pagoda start,
    required Pagoda end,
    required FerryConnection connection,
    required List<Pagoda> allPagodas,
  }) async {
    final gatewayId = connection.mainlandPagodaId;
    if (gatewayId == null || gatewayId.isEmpty) {
      return const PathSearchResult.empty();
    }

    Pagoda? gateway;
    for (final pagoda in allPagodas) {
      if (pagoda.id == gatewayId) {
        gateway = pagoda;
        break;
      }
    }
    if (gateway == null) {
      return const PathSearchResult.empty();
    }

    final startsAtFerryPagoda = start.id == connection.pagodaId;
    final legStart = startsAtFerryPagoda ? gateway : start;
    final legEnd = startsAtFerryPagoda ? end : gateway;
    if (legStart.id == legEnd.id) {
      return PathSearchResult(path: [legStart], distanceKm: 0);
    }

    // This path supplies visible route stops.  A remote pagoda may be far
    // from an offline road node, but that must not erase real pagodas between
    // it and the ferry gateway.
    final leg = await PathfindingService.findPath(
      legStart,
      legEnd,
      allPagodas,
      requireTrustedRoadAccess: false,
    );
    if (!leg.isEmpty && !leg.requiresRiverCrossing) {
      return leg;
    }
    return PathSearchResult(
      path: [legStart, legEnd],
      distanceKm: Helpers.calculateDistance(
        legStart.latitude,
        legStart.longitude,
        legEnd.latitude,
        legEnd.longitude,
      ),
    );
  }

  Future<void> _openCreateTrip() async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('trips.title'),
    );
    if (!canContinue || !mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(initialPagoda: _selectedPagoda),
      ),
    );
  }

  Future<void> _openTripDetail(Trip trip) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('trips.title'),
    );
    if (!canContinue || !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
    );
    if (!mounted) return;
    final refreshed = await context.read<TripProvider>().getTripById(trip.id);
    if (!mounted || refreshed == null) return;
    _selectTrip(refreshed);
  }

  Future<void> _openEditTrip(Trip trip) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('common.edit'),
    );
    if (!canContinue || !mounted) {
      return;
    }
    final updatedTrip = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(existingTrip: trip),
      ),
    );

    if (!mounted) return;
    if (updatedTrip is Trip) {
      _selectTrip(updatedTrip);
      return;
    }

    final refreshed = await context.read<TripProvider>().getTripById(trip.id);
    if (!mounted) return;
    if (refreshed != null) {
      _selectTrip(refreshed);
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('common.delete'),
    );
    if (!canContinue || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.translate('trips.deleteTitle')),
        content: Text(context.l10n.translate('trips.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.l10n.translate('common.delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TripProvider>().deleteTrip(trip.id);
    if (!mounted) return;

    if (_selectedTrip?.id == trip.id) {
      setState(() {
        _selectedTrip = null;
        _tripRoute = [];
        _isTripRouteFallback = false;
        _tripRouteSegments = [];
        _tripRouteUsesFerry = false;
        _isTripRouteLoading = false;
        _selectedPagoda = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoggedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('map.title')), elevation: 0),
      body: Consumer3<PagodaProvider, TripProvider, AuthProvider>(
        builder: (context, pagodaProvider, tripProvider, authProvider, _) {
          if (pagodaProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isLoggedIn = authProvider.user != null;
          final pagodas = pagodaProvider.allPagodas;
          final showTrip = _mode == MapTripMode.trips && _selectedTrip != null;
          final showPath =
              _mode == MapTripMode.path && _shortestPathRoute.isNotEmpty;
          final baseMarkers = switch (_mode) {
            MapTripMode.path => _buildPathMarkers(pagodas),
            MapTripMode.trips when showTrip && _selectedTrip != null =>
              _buildTripMarkers(_selectedTrip!, pagodas),
            _ => _buildPagodaMarkers(pagodas),
          };
          final markers = [
            ...baseMarkers,
            ..._buildFerryMarkers(
              showTrip ? _tripRouteSegments : _shortestPathRouteSegments,
            ),
          ];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    AppConstants.baganLatitude,
                    AppConstants.baganLongitude,
                  ),
                  initialZoom: AppConstants.defaultZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.mapTileUrlTemplate,
                    fallbackUrl: AppConstants.mapFallbackTileUrlTemplate,
                    subdomains: AppConstants.mapTileSubdomains,
                    userAgentPackageName: AppConstants.mapTileUserAgent,
                  ),
                  if (showTrip &&
                      _tripRoute.isNotEmpty &&
                      _tripRouteSegments.isEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _tripRoute,
                          color: const Color(0xFFD4AF37),
                          strokeWidth: 5,
                          borderStrokeWidth: 3,
                          borderColor: Colors.black.withValues(alpha: 0.25),
                          gradientColors: const [
                            Colors.green,
                            Color(0xFFD4AF37),
                            Colors.red,
                          ],
                          colorsStop: const [0.0, 0.5, 1.0],
                        ),
                      ],
                    ),
                  if (showTrip && _tripRouteSegments.isNotEmpty)
                    PolylineLayer(
                      polylines: _buildSegmentPolylines(_tripRouteSegments),
                    ),
                  if (showPath && _shortestPathRouteSegments.isEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _shortestPathRoute,
                          color: const Color(0xFFFF7F11),
                          strokeWidth: 6,
                          borderStrokeWidth: 4,
                          borderColor: Colors.black.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  if (showPath && _shortestPathRouteSegments.isNotEmpty)
                    PolylineLayer(
                      polylines: _buildSegmentPolylines(
                        _shortestPathRouteSegments,
                        roadColor: const Color(0xFFFF7F11),
                      ),
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),
              if (pagodas.isEmpty)
                Center(
                  child: Text(
                    l10n.translate('map.noPagodas'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: SafeArea(child: _buildModeToggle(context)),
              ),
              if ((showTrip && _isTripRouteFallback) ||
                  (_mode == MapTripMode.path && _isPathRouteFallback))
                Positioned(
                  top: 72,
                  right: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.translate('route.fallback'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              if ((showTrip && _tripRouteUsesFerry) ||
                  (_mode == MapTripMode.path && _shortestPathUsesFerry))
                Positioned(
                  top: 72,
                  left: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF166B91).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.translate('route.ferryRoute'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_mode == MapTripMode.path)
                Positioned.fill(child: _buildPathPanel(pagodas)),
              if (_mode == MapTripMode.trips)
                Positioned.fill(
                  child: _buildTripPanel(tripProvider, isLoggedIn: isLoggedIn),
                ),
              if (_selectedPagoda != null &&
                  (_mode == MapTripMode.browse ||
                      (_mode == MapTripMode.trips && _selectedTrip != null)))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.only(
                      bottom: _mode == MapTripMode.trips ? 108 : 8,
                    ),
                    child: _buildPagodaInfo(_selectedPagoda!),
                  ),
                ),
            ],
          );
        },
      ),
      // Path and trip sheets own their primary actions. Keeping the map FABs
      // in Browse mode prevents them from covering forms and panel buttons.
      floatingActionButton: _mode == MapTripMode.browse
          ? _buildFloatingActionButtons(isLoggedIn: isLoggedIn)
          : null,
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.95),
      child: Row(
        children: [
          _ModeToggleItem(
            selected: _mode == MapTripMode.browse,
            label: l10n.translate('map.mode.browse'),
            icon: Icons.map_outlined,
            activeColor: theme.colorScheme.primary,
            onTap: () => _setMode(MapTripMode.browse),
          ),
          _ModeToggleItem(
            selected: _mode == MapTripMode.path,
            label: l10n.translate('map.mode.path'),
            icon: Icons.alt_route,
            activeColor: theme.colorScheme.primary,
            onTap: () => _setMode(MapTripMode.path),
          ),
          _ModeToggleItem(
            selected: _mode == MapTripMode.trips,
            label: l10n.translate('map.planTrip'),
            icon: Icons.route,
            activeColor: theme.colorScheme.primary,
            onTap: () => _setMode(MapTripMode.trips),
          ),
        ],
      ),
    );
  }

  Widget _buildPathPanel(List<Pagoda> pagodas) {
    final l10n = context.l10n;
    final sortedPagodas = [...pagodas]
      ..sort(
        (a, b) => l10n
            .pagodaName(a.id, a.name, remoteMyanmar: a.nameMyanmar)
            .compareTo(
              l10n.pagodaName(b.id, b.name, remoteMyanmar: b.nameMyanmar),
            ),
      );
    final hasSelection = _pathStartPagoda != null || _pathEndPagoda != null;
    final canFind =
        _pathStartPagoda != null &&
        _pathEndPagoda != null &&
        _pathStartPagoda!.id != _pathEndPagoda!.id;
    final hasPath = _shortestPathSteps.length >= 2;
    final pathDistance = hasPath ? _shortestPathDistanceKm : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.24,
      maxChildSize: 0.76,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7D5BC)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate('map.pathTitle'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8D5E2F),
                          ),
                        ),
                      ),
                      if (_isPathRouteLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.translate('map.pathHelp'),
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  _buildPathDropdown(
                    label: l10n.translate('map.pathStart'),
                    value: _pathStartPagoda,
                    pagodas: sortedPagodas,
                    onChanged: _setPathStart,
                    accentColor: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildPathDropdown(
                    label: l10n.translate('map.pathEnd'),
                    value: _pathEndPagoda,
                    pagodas: sortedPagodas,
                    onChanged: _setPathEnd,
                    accentColor: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.translate('map.pathTapHint'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canFind && !_isPathRouteLoading
                              ? () => _loadShortestPath(pagodas)
                              : null,
                          icon: const Icon(Icons.alt_route),
                          label: Text(l10n.translate('map.pathFind')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFAA7739),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasSelection || hasPath
                              ? _clearPathSelection
                              : null,
                          icon: const Icon(Icons.close),
                          label: Text(l10n.translate('map.pathClear')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8D5E2F),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: canFind
                          ? () => _swapPathEndpoints(pagodas)
                          : null,
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.translate('common.swap')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_isPathRouteLoading)
              _buildPathMessageCard(
                icon: Icons.alt_route,
                message: l10n.translate('map.pathFinding'),
              )
            else if (hasPath) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAA7739), Color(0xFF8D5E2F)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('map.pathRouteFound'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPathSummaryItem(
                            icon: Icons.straighten,
                            label: l10n.translate('map.pathDistanceLabel'),
                            value: Helpers.formatDistance(
                              context,
                              pathDistance,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPathSummaryItem(
                            icon: Icons.temple_buddhist,
                            label: l10n.translate('map.pathStopsLabel'),
                            value: _shortestPathSteps.length.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_shortestPathUsesFerry) ...[
                _buildPathMessageCard(
                  icon: Icons.directions_boat_filled_rounded,
                  message: l10n.translate('route.ferryAvailability'),
                  iconColor: const Color(0xFF166B91),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                l10n.translate('map.pathRouteList'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8D5E2F),
                ),
              ),
              const SizedBox(height: 10),
              ..._shortestPathSteps.asMap().entries.map(
                (entry) => _buildPathStepCard(
                  step: entry.value,
                  index: entry.key,
                  total: _shortestPathSteps.length,
                ),
              ),
            ] else if (_hasAttemptedPathSearch)
              _buildPathMessageCard(
                icon: Icons.error_outline,
                message: l10n.translate('trip.noRouteFound'),
                iconColor: Colors.red,
              )
            else
              _buildPathMessageCard(
                icon: Icons.touch_app,
                message: l10n.translate('map.pathSelectPrompt'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathDropdown({
    required String label,
    required Pagoda? value,
    required List<Pagoda> pagodas,
    required ValueChanged<Pagoda?> onChanged,
    required Color accentColor,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
        prefixIcon: Icon(Icons.temple_buddhist, color: accentColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.25)),
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            context.l10n.translate('map.pathChoosePagoda'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...pagodas.map(
          (pagoda) => DropdownMenuItem<String>(
            value: pagoda.id,
            child: Text(
              context.l10n.pagodaName(
                pagoda.id,
                pagoda.name,
                remoteMyanmar: pagoda.nameMyanmar,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (selectedId) {
        Pagoda? selected;
        for (final pagoda in pagodas) {
          if (pagoda.id == selectedId) {
            selected = pagoda;
            break;
          }
        }
        onChanged(selected);
      },
    );
  }

  Widget _buildPathSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathStepCard({
    required MultimodalPathStep step,
    required int index,
    required int total,
  }) {
    final isStart = index == 0;
    final isEnd = index == total - 1;
    final isFerry = step.isFerryTerminal;
    final color = isStart
        ? Colors.green
        : isEnd
        ? Colors.red
        : isFerry
        ? const Color(0xFF166B91)
        : Colors.blue;
    final typeLabel = isStart
        ? context.l10n.translate('map.pathStartPoint')
        : isEnd
        ? context.l10n.translate('map.pathEndPoint')
        : isFerry
        ? context.l10n.translate('route.ferryTerminal')
        : context.l10n.translate('map.pathWaypoint');
    final displayName = step.pagoda != null
        ? context.l10n.pagodaName(
            step.pagoda!.id,
            step.pagoda!.name,
            remoteMyanmar: step.pagoda!.nameMyanmar,
          )
        : context.l10n.locale.languageCode == 'my'
        ? step.nameMyanmar
        : step.name;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final pagoda = step.pagoda;
          if (pagoda != null) {
            _focusPagoda(pagoda);
          } else {
            _mapController.move(step.location, AppConstants.defaultZoom + 2);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                isStart
                    ? Icons.play_arrow
                    : isEnd
                    ? Icons.flag
                    : isFerry
                    ? Icons.directions_boat_filled_rounded
                    : Icons.place_outlined,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathMessageCard({
    required IconData icon,
    required String message,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: iconColor ?? Colors.grey[600]),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildTripPanel(TripProvider provider, {required bool isLoggedIn}) {
    final label = context.l10n.translate('map.planTrip');
    final helper = context.l10n.translate('map.planHelp');

    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.12,
      maxChildSize: 0.6,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isTripRouteLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const SizedBox(width: 12),
                        if (isLoggedIn)
                          TextButton.icon(
                            onPressed: _openCreateTrip,
                            icon: const Icon(Icons.add),
                            label: Text(
                              context.l10n.translate('common.create'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      helper,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  if (_selectedTrip != null)
                    _buildSelectedTripSummary(_selectedTrip!),
                ],
              ),
            ),
            ..._buildTripListSlivers(provider, isLoggedIn: isLoggedIn),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTripListSlivers(
    TripProvider provider, {
    required bool isLoggedIn,
  }) {
    if (!isLoggedIn) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyTrips(isLoggedIn: false),
        ),
      ];
    }

    if (provider.isLoading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final trips = provider.trips;
    if (trips.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyTrips(isLoggedIn: true),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final trip = trips[index];
            final isSelected = _selectedTrip?.id == trip.id;
            return Card(
              elevation: isSelected ? 4 : 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: ListTile(
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFD4AF37),
                  child: Text('${trip.stops.length}'),
                ),
                title: Text(trip.name),
                subtitle: Text(
                  '${Helpers.formatDate(trip.date)} - ${context.l10n.translate('common.stopsCount', args: {'count': trip.stops.length.toString()})}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: context.l10n.translate('common.edit'),
                      onPressed: () => _openEditTrip(trip),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: context.l10n.translate('common.delete'),
                      onPressed: () => _deleteTrip(trip),
                    ),
                  ],
                ),
                onTap: () => _selectTrip(trip),
              ),
            );
          }, childCount: trips.length),
        ),
      ),
    ];
  }

  Widget _buildEmptyTrips({required bool isLoggedIn}) {
    if (!isLoggedIn) {
      return SignInRequiredView(
        icon: Icons.route,
        message: context.l10n.translate('trips.signInPrompt'),
        onSignIn: () {
          AuthGate.openSignIn(context);
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              context.l10n.translate('map.noTrips'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.translate('map.noTripsHint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCreateTrip,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.translate('map.createTrip')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTripSummary(Trip trip) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.translate('map.clearSelection'),
                  onPressed: () {
                    setState(() {
                      _selectedTrip = null;
                      _tripRoute = [];
                      _isTripRouteFallback = false;
                      _tripRouteSegments = [];
                      _tripRouteUsesFerry = false;
                      _isTripRouteLoading = false;
                      _selectedPagoda = null;
                    });
                  },
                ),
              ],
            ),
            Text(
              Helpers.formatDate(trip.date),
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.translate('map.tripSavedOrder'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildTripStat(
                  Icons.place,
                  context.l10n.translate(
                    'common.stopsCount',
                    args: {'count': trip.stops.length.toString()},
                  ),
                ),
                _buildTripStat(
                  Icons.straighten,
                  Helpers.formatDistance(context, trip.getTotalDistance()),
                ),
                _buildTripStat(
                  Helpers.transportModeIcon(trip.transportMode),
                  '${Helpers.transportModeLabel(context, trip.transportMode)}: '
                  '${Helpers.formatDuration(context, trip.getEstimatedTravelDuration())}',
                ),
                if (_tripRouteUsesFerry)
                  _buildTripStat(
                    Icons.directions_boat_filled_rounded,
                    context.l10n.translate('route.ferrySegment'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openTripDetail(trip),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(context.l10n.translate('map.details')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditTrip(trip),
                  icon: const Icon(Icons.edit),
                  label: Text(context.l10n.translate('common.edit')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteTrip(trip),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.translate('common.delete')),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  List<Marker> _buildPagodaMarkers(List<Pagoda> pagodas) {
    return pagodas.map((pagoda) {
      return Marker(
        point: LatLng(pagoda.latitude, pagoda.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _selectPagoda(pagoda),
          child: _MapMarker(
            isSelected: _selectedPagoda?.id == pagoda.id,
            pulse: _pulseController,
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildPathMarkers(List<Pagoda> pagodas) {
    final pathIndexes = <String, int>{};
    for (var i = 0; i < _shortestPathPagodas.length; i++) {
      pathIndexes[_shortestPathPagodas[i].id] = i;
    }

    return pagodas.map((pagoda) {
      final isStart = _pathStartPagoda?.id == pagoda.id;
      final isEnd = _pathEndPagoda?.id == pagoda.id;
      final pathIndex = pathIndexes[pagoda.id];

      return Marker(
        point: LatLng(pagoda.latitude, pagoda.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _handlePathPagodaTap(pagoda),
          child: _PathMapMarker(
            isStart: isStart,
            isEnd: isEnd,
            pathOrder: pathIndex == null || isStart || isEnd ? null : pathIndex,
            pulse: _pulseController,
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildTripMarkers(Trip trip, List<Pagoda> pagodas) {
    return trip.stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      final pagoda = _resolveTripStopPagoda(stop, pagodas);
      final color = index == 0
          ? Colors.green
          : index == trip.stops.length - 1
          ? Colors.red
          : const Color(0xFFD4AF37);

      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: pagoda == null
              ? null
              : () => _handleTripStopTap(stop, pagodas),
          child: _TripMapMarker(
            label: '${index + 1}',
            color: color,
            isSelected: _selectedPagoda?.id == stop.pagodaId,
            pulse: _pulseController,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPagodaInfo(Pagoda pagoda) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ResponsiveContent(
        child: Container(
          margin: EdgeInsets.all(Responsive.spacing(context)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: Responsive.cardPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.pagodaName(
                          pagoda.id,
                          pagoda.name,
                          remoteMyanmar: pagoda.nameMyanmar,
                        ),
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedPagoda = null;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: Responsive.smallSpacing(context)),
                Text(
                  context.l10n.pagodaDescription(
                    pagoda.id,
                    pagoda.description,
                    remoteMyanmar: pagoda.descriptionMyanmar,
                  ),
                  maxLines: Responsive.isDesktopOrLarger(context) ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: Responsive.responsiveFontSize(context, 14),
                  ),
                ),
                FutureBuilder<PagodaRouteGraphData?>(
                  future: PathfindingService.loadGraph(),
                  builder: (context, snapshot) {
                    final requiresRiverCrossing =
                        snapshot
                            .data
                            ?.nodes[pagoda.id]
                            ?.requiresRiverCrossing ??
                        false;
                    if (!requiresRiverCrossing) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_boat_outlined,
                            size: 18,
                            color: Color(0xFFA34A2A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.translate(
                                'route.riverCrossingLocation',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF786A5D),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: Responsive.spacing(context)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PagodaDetailScreen(pagoda: pagoda),
                        ),
                      );
                    },
                    child: Text(context.l10n.translate('map.viewDetails')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons({required bool isLoggedIn}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mode == MapTripMode.trips && isLoggedIn) ...[
          FloatingActionButton.small(
            heroTag: 'create-trip',
            onPressed: _openCreateTrip,
            child: const Icon(Icons.add),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
        ],
        if (_mode == MapTripMode.path && _shortestPathRoute.isNotEmpty) ...[
          FloatingActionButton.small(
            heroTag: 'focus-shortest-path',
            onPressed: () => _focusRoute(_shortestPathRoute),
            child: const Icon(Icons.alt_route),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
        ],
        if (_selectedPagoda != null &&
            (_mode == MapTripMode.browse ||
                (_mode == MapTripMode.trips && _selectedTrip != null))) ...[
          FloatingActionButton.small(
            heroTag: 'selected-pagoda',
            onPressed: () {
              final selected = _selectedPagoda;
              if (selected == null) {
                return;
              }
              _mapController.move(
                LatLng(selected.latitude, selected.longitude),
                AppConstants.defaultZoom + 2,
              );
            },
            child: const Icon(Icons.place),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
        ],
        FloatingActionButton(
          heroTag: 'reset-map',
          onPressed: () {
            _mapController.move(
              LatLng(AppConstants.baganLatitude, AppConstants.baganLongitude),
              AppConstants.defaultZoom,
            );
          },
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }
}

class _ModeToggleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeToggleItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: Responsive.isCompact(context) ? 36 : 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : activeColor,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : activeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.responsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathMapMarker extends StatelessWidget {
  final bool isStart;
  final bool isEnd;
  final int? pathOrder;
  final Animation<double> pulse;

  const _PathMapMarker({
    required this.isStart,
    required this.isEnd,
    required this.pathOrder,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final isPathNode = pathOrder != null;
    final markerColor = isStart
        ? Colors.green
        : isEnd
        ? Colors.red
        : isPathNode
        ? Colors.blue
        : const Color(0xFF8B4513);

    final child = isStart
        ? const Text(
            'A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          )
        : isEnd
        ? const Text(
            'B',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          )
        : isPathNode
        ? Text(
            '$pathOrder',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          )
        : const Icon(Icons.temple_buddhist, color: Colors.white, size: 20);

    final marker = Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: child),
    );

    if (!isStart && !isEnd) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.4,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0.0).animate(pulse),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}

class _MapMarker extends StatelessWidget {
  final bool isSelected;
  final Animation<double> pulse;

  const _MapMarker({required this.isSelected, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF8B4513),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.temple_buddhist, color: Colors.white, size: 20),
    );

    if (!isSelected) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.4,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 0.0).animate(pulse),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}

class _TripMapMarker extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final Animation<double> pulse;

  const _TripMapMarker({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF5C3A17) : Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (!isSelected) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.82,
            end: 1.38,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.42, end: 0.0).animate(pulse),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}
