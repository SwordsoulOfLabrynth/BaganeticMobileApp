import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/device_location_service.dart';
import '../../../core/services/logger.dart';
import '../../../core/services/multimodal_route_service.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/offline_route_service.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/bagan_map_coverage.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/pathfinding.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/travel_place.dart';
import '../../../data/services/travel_place_data_service.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sign_in_required_view.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../discover/travel_discovery_screen.dart';
import '../trips/create_trip_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../../../core/localization/app_localizations.dart';
import 'widgets/map_markers.dart';

enum MapTripMode { browse, path, trips }

enum MapBrowseCategory { all, pagodas, stays, food, transport, scenery }

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
  TravelPlace? _selectedTravelPlace;
  late final Future<List<TravelPlace>> _travelPlacesFuture;
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
  bool _isPathMapFocus = false;
  late MapTripMode _mode;
  late final AnimationController _pulseController;
  final DeviceLocationService _locationService = DeviceLocationService();
  StreamSubscription<LatLng>? _locationSub;
  LatLng? _userLocation;
  var _isLocating = false;
  OfflineMapStatus? _offlineMapStatus;
  var _isOfflineMapRetrying = false;
  MapBrowseCategory _browseCategory = MapBrowseCategory.all;
  double _mapZoom = AppConstants.defaultZoom;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _travelPlacesFuture = const TravelPlaceDataService().loadPlaces();
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
    OfflineMapService.instance.statusNotifier.addListener(
      _onOfflineMapStatusChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startLocationWatch());
      unawaited(_refreshOfflineMapStatus());
    });
  }

  @override
  void dispose() {
    OfflineMapService.instance.statusNotifier.removeListener(
      _onOfflineMapStatusChanged,
    );
    _locationSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onOfflineMapStatusChanged() {
    if (mounted) {
      setState(() {
        _offlineMapStatus = OfflineMapService.instance.statusNotifier.value;
      });
    }
  }

  Future<void> _startLocationWatch() async {
    try {
      await _locationSub?.cancel();
      _locationSub = _locationService.watchLocation().listen(
        (point) {
          if (!mounted) {
            return;
          }
          setState(() => _userLocation = point);
        },
        onError: (Object error, StackTrace stackTrace) {
          Logger.error('Live location updates stopped', error, stackTrace);
        },
      );
    } on DeviceLocationException {
      // Permission can be granted later from the locate button.
    } catch (e, stackTrace) {
      Logger.error('Could not start live location', e, stackTrace);
    }
  }

  Future<void> _goToUserLocation() async {
    if (_isLocating) {
      return;
    }
    setState(() => _isLocating = true);
    final l10n = context.l10n;
    try {
      final point = await _locationService.getCurrentLocation();
      if (!mounted) {
        return;
      }
      setState(() => _userLocation = point);
      _mapController.move(point, AppConstants.userLocationZoom);
      if (!BaganMapCoverage.contains(point)) {
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationOutsideBagan'),
        );
      }
      unawaited(_startLocationWatch());
    } on DeviceLocationException catch (error) {
      if (!mounted) {
        return;
      }
      await _handleLocationError(error.code);
    } catch (e, stackTrace) {
      Logger.error('Locate me failed', e, stackTrace);
      if (mounted) {
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationUnavailable'),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _handleLocationError(DeviceLocationError code) async {
    final l10n = context.l10n;
    switch (code) {
      case DeviceLocationError.servicesDisabled:
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationServicesOff'),
          isError: true,
        );
        await _locationService.openLocationSettings();
        break;
      case DeviceLocationError.permissionDenied:
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationPermissionDenied'),
          isError: true,
        );
        break;
      case DeviceLocationError.permissionDeniedForever:
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationPermissionDeniedForever'),
          isError: true,
        );
        await _locationService.openAppSettings();
        break;
      case DeviceLocationError.unavailable:
        Helpers.showSnackBar(
          context,
          l10n.translate('map.locationUnavailable'),
          isError: true,
        );
        break;
    }
  }

  Future<void> _refreshOfflineMapStatus() async {
    try {
      final status = await OfflineMapService.instance.getStatus();
      if (mounted) {
        setState(() => _offlineMapStatus = status);
      }
    } catch (error, stackTrace) {
      Logger.error('Could not read offline map status', error, stackTrace);
    }
  }

  Future<void> _retryOfflineMapDownload() async {
    if (_isOfflineMapRetrying) {
      return;
    }

    setState(() => _isOfflineMapRetrying = true);
    try {
      await OfflineMapService.instance.startBackgroundPrefetch(force: true);
      await _refreshOfflineMapStatus();
    } catch (error, stackTrace) {
      Logger.error('Could not retry offline map download', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isOfflineMapRetrying = false);
      }
    }
  }

  void _resetToBaganOverview() {
    _mapController.move(
      LatLng(AppConstants.baganLatitude, AppConstants.baganLongitude),
      AppConstants.defaultZoom,
    );
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
      _isPathMapFocus =
          mode == MapTripMode.path && _shortestPathRoute.isNotEmpty;
      if (mode != MapTripMode.browse) {
        _selectedTravelPlace = null;
      }
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
      _isPathMapFocus = false;
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
      _selectedTravelPlace = null;
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
      _isPathMapFocus = false;
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
        _isPathMapFocus = false;
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
      _isPathMapFocus = false;
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
        _isPathMapFocus = true;
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
      _isPathMapFocus = true;
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('map.title')), elevation: 0),
      body: FutureBuilder<List<TravelPlace>>(
        future: _travelPlacesFuture,
        builder: (context, travelPlacesSnapshot) =>
            Consumer3<PagodaProvider, TripProvider, AuthProvider>(
              builder: (context, pagodaProvider, tripProvider, authProvider, _) {
          if (pagodaProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isLoggedIn = authProvider.user != null;
          final pagodas = pagodaProvider.allPagodas;
          final travelPlaces = travelPlacesSnapshot.data ?? const <TravelPlace>[];
          final browsePagodas = _browseCategory == MapBrowseCategory.all ||
                  _browseCategory == MapBrowseCategory.pagodas
              ? pagodas
              : const <Pagoda>[];
          final browseTravelPlaces = _browseCategory == MapBrowseCategory.all
              ? travelPlaces
              : travelPlaces
                  .where(
                    (place) => place.category == _travelPlaceCategoryForBrowse(),
                  )
                  .toList(growable: false);
          final showTrip = _mode == MapTripMode.trips && _selectedTrip != null;
          final showPath =
              _mode == MapTripMode.path && _shortestPathRoute.isNotEmpty;
          final shouldClusterMarkers =
              _mode == MapTripMode.browse ||
              (_mode == MapTripMode.trips && !showTrip);
          final baseMarkers = switch (_mode) {
            MapTripMode.path => _buildPathMarkers(pagodas),
            MapTripMode.trips when showTrip && _selectedTrip != null =>
              _buildTripMarkers(_selectedTrip!, pagodas),
            _ => [
                ..._buildPagodaMarkers(browsePagodas),
                ..._buildTravelPlaceMarkers(browseTravelPlaces),
              ],
          };
          final auxiliaryMarkers = [
            ..._buildFerryMarkers(
              showTrip ? _tripRouteSegments : _shortestPathRouteSegments,
            ),
            if (_userLocation != null) _buildUserLocationMarker(_userLocation!),
          ];
          final overviewMarkers =
              _mode == MapTripMode.browse && _mapZoom < 10.5
              ? _buildBrowseAreaMarkers(browsePagodas)
              : const <Marker>[];

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
                  onPositionChanged: (camera, _) {
                    if (!mounted || (camera.zoom - _mapZoom).abs() < 0.01) {
                      return;
                    }
                    setState(() => _mapZoom = camera.zoom);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.mapTileUrlTemplate,
                    fallbackUrl: AppConstants.mapFallbackTileUrlTemplate,
                    subdomains: AppConstants.mapTileSubdomains,
                    userAgentPackageName: AppConstants.mapTileUserAgent,
                    tileProvider: FMTCTileProvider(
                      stores: {
                        AppConstants.mapTileStore:
                            BrowseStoreStrategy.readUpdateCreate,
                      },
                    ),
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
                  if (overviewMarkers.isNotEmpty)
                    MarkerLayer(markers: overviewMarkers)
                  else if (shouldClusterMarkers)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        markers: baseMarkers,
                        maxClusterRadius: 34,
                        size: const Size(32, 32),
                        padding: const EdgeInsets.all(48),
                        maxZoom: 17,
                        disableClusteringAtZoom: 14,
                        zoomToBoundsOnClick: true,
                        spiderfyCluster: true,
                        showPolygon: false,
                        markerChildBehavior: true,
                        builder: (context, clusteredMarkers) =>
                            MapClusterMarker(
                              count: clusteredMarkers.length,
                              color: _browseCategoryColor(_browseCategory),
                            ),
                      ),
                    )
                  else
                    MarkerLayer(markers: baseMarkers),
                  MarkerLayer(markers: auxiliaryMarkers),
                ],
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.translate('map.osmAttribution'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF5C534C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (pagodas.isEmpty && travelPlaces.isEmpty)
                Center(
                  child: Text(
                    l10n.translate('map.noPagodas'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              if (_mode == MapTripMode.browse &&
                  (pagodas.isNotEmpty || travelPlaces.isNotEmpty) &&
                  browsePagodas.isEmpty &&
                  browseTravelPlaces.isEmpty)
                Center(child: _buildEmptyBrowseCategory()),
              if (_mode != MapTripMode.browse)
                Positioned(
                  right: 12,
                  bottom: _mode == MapTripMode.trips ? 120 : 36,
                  child: _buildLocateButton(),
                ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: SafeArea(child: _buildModeToggle(context)),
              ),
              if (_mode == MapTripMode.browse)
                Positioned(
                  top: 72,
                  left: 0,
                  right: 0,
                  child: SafeArea(top: false, child: _buildCategoryFilters()),
                ),
              if (_mode == MapTripMode.browse)
                Positioned(
                  top: 128,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    top: false,
                    child: _buildOfflineMapStatus(),
                  ),
                ),
              if (showTrip && _isTripRouteFallback)
                Positioned(
                  top: 218,
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
              if (showTrip && _tripRouteUsesFerry)
                Positioned(
                  top: 218,
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
              if (_mode == MapTripMode.path && !_isPathMapFocus)
                Positioned.fill(child: _buildPathPanel(pagodas)),
              if (_mode == MapTripMode.path && _isPathMapFocus)
                Positioned(
                  top: 84,
                  left: 16,
                  child: SafeArea(
                    top: false,
                    child: _buildPathControlsButton(),
                  ),
                ),
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
              if (_selectedTravelPlace != null && _mode == MapTripMode.browse)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: _buildTravelPlaceInfo(_selectedTravelPlace!),
                  ),
                ),
              if (_mode == MapTripMode.browse)
                Positioned(
                  right: 16,
                  bottom: _selectedPagoda == null && _selectedTravelPlace == null
                      ? 24
                      : 196,
                  child: _buildFloatingActionButtons(isLoggedIn: isLoggedIn),
                ),
            ],
          );
              },
            ),
      ),
    );
  }

  Future<void> _openTripPlannerAction() async {
    final selectedTrip = _selectedTrip;
    if (selectedTrip != null) {
      await _openEditTrip(selectedTrip);
      return;
    }
    await _openCreateTrip();
  }

  Widget _buildOfflineMapStatus() {
    final status = _offlineMapStatus;
    if (status == null || status == OfflineMapStatus.ready) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final isDownloading = status == OfflineMapStatus.downloading;
    final messageKey = switch (status) {
      OfflineMapStatus.notDownloaded => 'map.offlineMapDownloadRequired',
      OfflineMapStatus.downloading => 'map.offlineMapDownloading',
      OfflineMapStatus.partial => 'map.offlineMapPartial',
      OfflineMapStatus.failed => 'map.offlineMapFailed',
      OfflineMapStatus.ready => throw StateError('Ready status is hidden'),
    };

    return Semantics(
      liveRegion: true,
      label: l10n.translate(messageKey),
      child: Material(
        color: const Color(0xFF30251D).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                isDownloading
                    ? Icons.downloading_rounded
                    : Icons.download_for_offline_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.translate(messageKey),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              if (!isDownloading)
                TextButton(
                  onPressed: _isOfflineMapRetrying
                      ? null
                      : _retryOfflineMapDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD995),
                    minimumSize: const Size(48, 48),
                  ),
                  child: _isOfflineMapRetrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.translate('map.offlineMapRetry')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.97),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE7D5BC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          children: [
            if (Responsive.isDesktopOrLarger(context))
              Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.temple_buddhist_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('map.title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                          color: const Color(0xFF30251D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.translate('map.title'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF786A5D),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E4CE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _mode == MapTripMode.browse
                        ? Icons.explore_outlined
                        : _mode == MapTripMode.path
                        ? Icons.alt_route_rounded
                        : Icons.route_rounded,
                    color: const Color(0xFFA34A2A),
                    size: 21,
                  ),
                ),
              ],
            ),
            if (Responsive.isDesktopOrLarger(context))
              const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E4CE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ModeToggleItem(
                    selected: _mode == MapTripMode.browse,
                    label: l10n.translate('map.mode.browse'),
                    icon: Icons.explore_outlined,
                    activeColor: theme.colorScheme.primary,
                    onTap: () => _setMode(MapTripMode.browse),
                  ),
                  ModeToggleItem(
                    selected: _mode == MapTripMode.path,
                    label: l10n.translate('map.mode.path'),
                    icon: Icons.alt_route_rounded,
                    activeColor: theme.colorScheme.primary,
                    onTap: () => _setMode(MapTripMode.path),
                  ),
                  ModeToggleItem(
                    selected: _mode == MapTripMode.trips,
                    label: l10n.translate('map.planTrip'),
                    icon: Icons.route_rounded,
                    activeColor: theme.colorScheme.primary,
                    onTap: () => _setMode(MapTripMode.trips),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: const Color(0xFFFFFBF3).withValues(alpha: .97),
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: MapCategoryChip(
                  label: context.l10n.translate('map.allPlaces'),
                  icon: _browseCategoryIcon(MapBrowseCategory.all),
                  color: _browseCategoryColor(MapBrowseCategory.all),
                  selected: _browseCategory == MapBrowseCategory.all,
                  showLabel: true,
                  onTap: () => _selectBrowseCategory(MapBrowseCategory.all),
                ),
              ),
              for (final category in MapBrowseCategory.values.skip(1))
                Expanded(
                  child: MapCategoryChip(
                    label: _browseCategoryLabel(category),
                    icon: _browseCategoryIcon(category),
                    color: _browseCategoryColor(category),
                    selected: _browseCategory == category,
                    onTap: () => _selectBrowseCategory(category),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectBrowseCategory(MapBrowseCategory category) {
    setState(() {
      _browseCategory = category;
      _selectedPagoda = null;
      _selectedTravelPlace = null;
    });
  }

  Widget _buildEmptyBrowseCategory() {
    final l10n = context.l10n;
    final label = _browseCategoryLabel(_browseCategory);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 136, 48, 144),
      child: Material(
        color: const Color(0xFFFFFBF3).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _browseCategoryIcon(_browseCategory),
                color: _browseCategoryColor(_browseCategory),
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.translate(
                  'map.categoryEmptyTitle',
                  args: {'category': label},
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF30251D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('map.categoryEmptyBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF786A5D),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _browseCategoryLabel(MapBrowseCategory category) {
    return context.l10n.translate(
      switch (category) {
        MapBrowseCategory.all => 'map.category.all',
        MapBrowseCategory.pagodas => 'map.category.pagodas',
        MapBrowseCategory.stays => 'map.category.stays',
        MapBrowseCategory.food => 'map.category.food',
        MapBrowseCategory.transport => 'map.category.transport',
        MapBrowseCategory.scenery => 'map.category.scenery',
      },
    );
  }

  IconData _browseCategoryIcon(MapBrowseCategory category) {
    return switch (category) {
      MapBrowseCategory.all => Icons.grid_view_rounded,
      MapBrowseCategory.pagodas => Icons.temple_buddhist_rounded,
      MapBrowseCategory.stays => Icons.bed_rounded,
      MapBrowseCategory.food => Icons.restaurant_rounded,
      MapBrowseCategory.transport => Icons.directions_transit_rounded,
      MapBrowseCategory.scenery => Icons.photo_camera_outlined,
    };
  }

  Color _browseCategoryColor(MapBrowseCategory category) {
    return switch (category) {
      MapBrowseCategory.all => const Color(0xFFA34A2A),
      // Category hues are deliberately distinct so the icon-only filters can
      // be recognized at a glance, including when one is selected.
      MapBrowseCategory.pagodas => const Color(0xFF8A5A12),
      MapBrowseCategory.stays => const Color(0xFF5C527F),
      MapBrowseCategory.food => const Color(0xFFBE123C),
      MapBrowseCategory.transport => const Color(0xFF006D77),
      MapBrowseCategory.scenery => const Color(0xFF2F7A49),
    };
  }

  TravelPlaceCategory? _travelPlaceCategoryForBrowse() {
    return switch (_browseCategory) {
      MapBrowseCategory.stays => TravelPlaceCategory.stay,
      MapBrowseCategory.food => TravelPlaceCategory.food,
      MapBrowseCategory.transport => TravelPlaceCategory.transport,
      MapBrowseCategory.scenery => TravelPlaceCategory.scenery,
      MapBrowseCategory.all || MapBrowseCategory.pagodas => null,
    };
  }

  MapBrowseCategory _browseCategoryForTravelPlace(
    TravelPlaceCategory category,
  ) {
    return switch (category) {
      TravelPlaceCategory.stay => MapBrowseCategory.stays,
      TravelPlaceCategory.food => MapBrowseCategory.food,
      TravelPlaceCategory.transport => MapBrowseCategory.transport,
      TravelPlaceCategory.scenery => MapBrowseCategory.scenery,
    };
  }

  Widget _buildPathPanel(List<Pagoda> pagodas) {
    final l10n = context.l10n;
    final sortedPagodas = [...pagodas]
      ..sort(
        (a, b) => l10n
            .pagodaName(a.id, a.name, remoteMyanmar: a.nameMyanmar)
            .compareTo(
              l10n.pagodaName(
                b.id,
                b.name,
                remoteMyanmar: b.nameMyanmar,
              ),
            ),
      );
    final canFind =
        _pathStartPagoda != null &&
        _pathEndPagoda != null &&
        _pathStartPagoda!.id != _pathEndPagoda!.id;
    final hasSelection = _pathStartPagoda != null || _pathEndPagoda != null;
    final hasPath = _shortestPathSteps.length >= 2;

    return Stack(
      children: [
        Positioned(
          top: 84,
          left: 16,
          right: 16,
          child: _buildPathBuilderCard(
            pagodas: sortedPagodas,
            canSwap: canFind,
            hasSelection: hasSelection,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: _buildPathActionCard(
            pagodas: pagodas,
            canFind: canFind,
            hasPath: hasPath,
          ),
        ),
      ],
    );
  }

  Widget _buildPathControlsButton() {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.translate('map.pathShowControls'),
      child: Tooltip(
        message: l10n.translate('map.pathShowControls'),
        child: Material(
          color: const Color(0xFFFFFBF3).withValues(alpha: 0.98),
          elevation: 4,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _isPathMapFocus = false),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.tune_rounded,
                color: Color(0xFFA34A2A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPathBuilderCard({
    required List<Pagoda> pagodas,
    required bool canSwap,
    required bool hasSelection,
  }) {
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  color: Color(0xFFA34A2A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.translate('map.pathTitle'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF30251D),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.translate('common.swap'),
                  onPressed: canSwap ? () => _swapPathEndpoints(pagodas) : null,
                  icon: const Icon(Icons.swap_vert_rounded),
                  color: const Color(0xFFA34A2A),
                ),
                if (hasSelection)
                  TextButton.icon(
                    onPressed: _clearPathSelection,
                    icon: const Icon(Icons.restart_alt_rounded, size: 19),
                    label: Text(l10n.translate('map.pathReset')),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFA34A2A),
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                Tooltip(
                  message: l10n.translate('map.pathHideControls'),
                  child: Material(
                    color: const Color(0xFFF0E4CE),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _isPathMapFocus = true),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFFA34A2A),
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildPathDropdown(
              label: l10n.translate('map.pathFrom'),
              value: _pathStartPagoda,
              pagodas: pagodas,
              onChanged: _setPathStart,
              accentColor: const Color(0xFFA34A2A),
            ),
            const SizedBox(height: 8),
            _buildPathDropdown(
              label: l10n.translate('map.pathTo'),
              value: _pathEndPagoda,
              pagodas: pagodas,
              onChanged: _setPathEnd,
              accentColor: const Color(0xFFA34A2A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathActionCard({
    required List<Pagoda> pagodas,
    required bool canFind,
    required bool hasPath,
  }) {
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isPathRouteFallback) ...[
              Text(
                l10n.translate('route.fallback'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF786A5D),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_shortestPathUsesFerry) ...[
              Text(
                l10n.translate('route.ferryRoute'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF166B91),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasPath) ...[
              Row(
                children: [
                  const Icon(
                    Icons.route_rounded,
                    color: Color(0xFFA34A2A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${Helpers.formatDistance(context, _shortestPathDistanceKm)} · '
                      '${_shortestPathSteps.length} ${l10n.translate('map.pathStopsLabel')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF30251D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showPathDetails,
                    child: Text(l10n.translate('map.details')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (_isPathRouteLoading) ...[
              const LinearProgressIndicator(color: Color(0xFFA34A2A)),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: canFind && !_isPathRouteLoading
                  ? () => _loadShortestPath(pagodas)
                  : null,
              icon: const Icon(Icons.alt_route_rounded),
              label: Text(
                _isPathRouteLoading
                    ? l10n.translate('map.pathFinding')
                    : l10n.translate('map.pathFind'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA34A2A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPathDetails() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.36,
        maxChildSize: 0.88,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF3),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: _shortestPathSteps.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  context.l10n.translate('map.pathRouteList'),
                  style: Theme.of(context).textTheme.headlineSmall,
                );
              }
              return _buildPathStepCard(
                step: _shortestPathSteps[index - 1],
                index: index - 1,
                total: _shortestPathSteps.length,
              );
            },
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyPathSheet(List<Pagoda> pagodas) {
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
    final l10n = context.l10n;
    final displayName = value == null
        ? l10n.translate('map.pathChoosePagoda')
        : l10n.pagodaName(
            value.id,
            value.name,
            remoteMyanmar: value.nameMyanmar,
          );

    return Semantics(
      button: true,
      label: '$label: $displayName',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showPathPagodaPicker(
            label: label,
            value: value,
            pagodas: pagodas,
            onChanged: onChanged,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.36)),
            ),
            child: Row(
              children: [
                Icon(Icons.temple_buddhist_rounded, color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: value == null
                              ? const Color(0xFF786A5D)
                              : const Color(0xFF30251D),
                          fontWeight:
                              value == null ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.search_rounded, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPathPagodaPicker({
    required String label,
    required Pagoda? value,
    required List<Pagoda> pagodas,
    required ValueChanged<Pagoda?> onChanged,
  }) async {
    final searchController = TextEditingController();
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = query.trim().toLowerCase();
          final matches = pagodas.where((pagoda) {
            if (normalizedQuery.isEmpty) {
              return true;
            }
            final localizedName = context.l10n.pagodaName(
              pagoda.id,
              pagoda.name,
              remoteMyanmar: pagoda.nameMyanmar,
            );
            return '$localizedName ${pagoda.name} ${pagoda.nameMyanmar ?? ''}'
                .toLowerCase()
                .contains(normalizedQuery);
          }).toList(growable: false);

          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) => Material(
              color: const Color(0xFFFFFBF3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0D1BE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (nextQuery) =>
                            setSheetState(() => query = nextQuery),
                        decoration: InputDecoration(
                          hintText: context.l10n.translate(
                            'map.pathSearchPagoda',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).deleteButtonTooltip,
                                  onPressed: () {
                                    searchController.clear();
                                    setSheetState(() => query = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: matches.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  context.l10n.translate(
                                    'map.pathNoPagodaMatches',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: matches.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final pagoda = matches[index];
                                final displayName = context.l10n.pagodaName(
                                  pagoda.id,
                                  pagoda.name,
                                  remoteMyanmar: pagoda.nameMyanmar,
                                );
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minVerticalPadding: 10,
                                  leading: const Icon(
                                    Icons.temple_buddhist_rounded,
                                    color: Color(0xFFA34A2A),
                                  ),
                                  title: Text(
                                    displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  selected: value?.id == pagoda.id,
                                  onTap: () {
                                    onChanged(pagoda);
                                    Navigator.of(sheetContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
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
        borderRadius: BorderRadius.circular(14),
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
    return Stack(
      children: [
        Positioned(
          top: 84,
          left: 16,
          right: 16,
          child: _buildTripPlannerCard(isLoggedIn: isLoggedIn),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: _buildSavedTripsBar(provider, isLoggedIn: isLoggedIn),
        ),
      ],
    );
  }

  Widget _buildTripPlannerCard({required bool isLoggedIn}) {
    final l10n = context.l10n;
    final selectedTrip = _selectedTrip;
    final isEditingTrip = selectedTrip != null;
    return Material(
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0E4CE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Color(0xFFA34A2A),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditingTrip
                        ? selectedTrip.name
                        : l10n.translate('map.tripPlannerTitle'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF30251D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEditingTrip
                        ? l10n.translate(
                            'map.tripPlannerSelectedHint',
                            args: {
                              'count': selectedTrip.stops.length.toString(),
                            },
                          )
                        : l10n.translate('map.tripPlannerHint'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF786A5D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: isLoggedIn ? _openTripPlannerAction : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA34A2A),
                side: const BorderSide(color: Color(0xFFA34A2A)),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                l10n.translate(
                  isEditingTrip ? 'map.addStop' : 'map.createTrip',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTripsBar(
    TripProvider provider, {
    required bool isLoggedIn,
  }) {
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.translate('map.savedTrips'),
              child: InkWell(
                onTap: () => _showSavedTrips(
                  provider,
                  isLoggedIn: isLoggedIn,
                ),
                borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E4CE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Color(0xFFA34A2A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            l10n.translate('map.savedTrips'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF30251D),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFA34A2A),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavedTrips(
    TripProvider provider, {
    required bool isLoggedIn,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildTripSheet(
        provider,
        isLoggedIn: isLoggedIn,
        initialChildSize: 0.62,
      ),
    );
  }

  Widget _buildTripSheet(
    TripProvider provider, {
    required bool isLoggedIn,
    double initialChildSize = 0.62,
  }) {
    final label = context.l10n.translate('map.savedTrips');

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: 0.20,
      maxChildSize: 0.82,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF3),
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

  IconData _travelPlaceIcon(TravelPlaceCategory category) {
    return switch (category) {
      TravelPlaceCategory.stay => Icons.bed_rounded,
      TravelPlaceCategory.food => Icons.restaurant_rounded,
      TravelPlaceCategory.transport => Icons.directions_transit_rounded,
      TravelPlaceCategory.scenery => Icons.photo_camera_outlined,
    };
  }

  Color _travelPlaceColor(TravelPlaceCategory category) {
    return _browseCategoryColor(_browseCategoryForTravelPlace(category));
  }

  List<Marker> _buildTravelPlaceMarkers(List<TravelPlace> places) {
    return places
        .map(
          (place) => Marker(
            point: LatLng(place.latitude, place.longitude),
            width: 38,
            height: 38,
            child: Semantics(
              button: true,
              label: '${place.name}, ${place.area}',
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedPagoda = null;
                  _selectedTravelPlace = place;
                }),
                child: TravelPlaceMapMarker(
                  icon: _travelPlaceIcon(place.category),
                  color: _travelPlaceColor(place.category),
                  isSelected: _selectedTravelPlace?.id == place.id,
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Marker> _buildPagodaMarkers(List<Pagoda> pagodas) {
    return pagodas.map((pagoda) {
      return Marker(
        point: LatLng(pagoda.latitude, pagoda.longitude),
        width: 32,
        height: 32,
        child: Semantics(
          button: true,
          label: context.l10n.pagodaName(
            pagoda.id,
            pagoda.name,
            remoteMyanmar: pagoda.nameMyanmar,
          ),
          child: GestureDetector(
            onTap: () => _selectPagoda(pagoda),
            child: PagodaMapMarker(
              isSelected: _selectedPagoda?.id == pagoda.id,
              pulse: _pulseController,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildBrowseAreaMarkers(List<Pagoda> pagodas) {
    final areas = <String, List<Pagoda>>{};
    for (final pagoda in pagodas) {
      final areaKey = switch (pagoda.latitude) {
        >= 21.182 => 'map.area.nyaungU',
        <= 21.148 => 'map.area.newBagan',
        _ => 'map.area.oldBagan',
      };
      areas.putIfAbsent(areaKey, () => []).add(pagoda);
    }

    return areas.entries.map((entry) {
      final areaPagodas = entry.value;
      final center = LatLng(
        areaPagodas.map((pagoda) => pagoda.latitude).reduce((a, b) => a + b) /
            areaPagodas.length,
        areaPagodas
                .map((pagoda) => pagoda.longitude)
                .reduce((a, b) => a + b) /
            areaPagodas.length,
      );
      final label = context.l10n.translate(entry.key);
      return Marker(
        point: center,
        width: 122,
        height: 36,
        child: Semantics(
          button: true,
          label: '$label, ${areaPagodas.length}',
          child: GestureDetector(
            onTap: () => _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(
                  areaPagodas
                      .map(
                        (pagoda) => LatLng(pagoda.latitude, pagoda.longitude),
                      )
                      .toList(growable: false),
                ),
                padding: const EdgeInsets.all(72),
              ),
            ),
            child: MapAreaMarker(
              label: label,
              count: areaPagodas.length,
              color: _browseCategoryColor(_browseCategory),
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }

  List<Marker> _buildPathMarkers(List<Pagoda> pagodas) {
    final pathIndexes = <String, int>{};
    for (var i = 0; i < _shortestPathPagodas.length; i++) {
      pathIndexes[_shortestPathPagodas[i].id] = i;
    }

    final visiblePagodas = _shortestPathPagodas.isEmpty
        ? pagodas
        : pagodas.where((pagoda) {
            return pathIndexes.containsKey(pagoda.id) ||
                pagoda.id == _pathStartPagoda?.id ||
                pagoda.id == _pathEndPagoda?.id;
          }).toList(growable: false);

    return visiblePagodas.map((pagoda) {
      final isStart = _pathStartPagoda?.id == pagoda.id;
      final isEnd = _pathEndPagoda?.id == pagoda.id;
      final pathIndex = pathIndexes[pagoda.id];

      return Marker(
        point: LatLng(pagoda.latitude, pagoda.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _handlePathPagodaTap(pagoda),
          child: PathMapMarker(
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
          child: TripMapMarker(
            label: '${index + 1}',
            color: color,
            isSelected: _selectedPagoda?.id == stop.pagodaId,
            pulse: _pulseController,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTravelPlaceInfo(TravelPlace place) {
    final theme = Theme.of(context);
    final isMyanmar = Localizations.localeOf(context).languageCode == 'my';
    final summary = isMyanmar ? place.summaryMyanmar : place.summary;
    final note = isMyanmar ? place.noteMyanmar : place.note;
    final color = _travelPlaceColor(place.category);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ResponsiveContent(
        child: Container(
          margin: EdgeInsets.fromLTRB(
            Responsive.spacing(context),
            0,
            Responsive.spacing(context),
            Responsive.spacing(context),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF3),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCCCB3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_travelPlaceIcon(place.category), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_browseCategoryLabel(_browseCategoryForTravelPlace(place.category))}  •  ${place.area}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                                letterSpacing: 0.55,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: context.l10n.translate('map.clearSelection'),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  setState(() => _selectedTravelPlace = null),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isMyanmar ? place.nameMyanmar : place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF30251D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF786A5D),
                          height: 1.28,
                        ),
                      ),
                      const SizedBox(height: 6),
                       Text(
                         note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF5C534C),
                          height: 1.25,
                         ),
                       ),
                       const SizedBox(height: 2),
                       Align(
                         alignment: Alignment.centerRight,
                         child: TextButton.icon(
                           onPressed: () => Navigator.of(context).push(
                             MaterialPageRoute<void>(
                               builder: (_) => TravelPlaceDetailScreen(
                                 place: place,
                               ),
                             ),
                           ),
                           icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                           label: Text(
                             context.l10n.translate('common.viewDetails'),
                           ),
                           style: TextButton.styleFrom(
                             foregroundColor: color,
                             minimumSize: const Size(48, 48),
                           ),
                         ),
                       ),
                     ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagodaInfo(Pagoda pagoda) {
    final theme = Theme.of(context);
    final title = context.l10n.pagodaName(
      pagoda.id,
      pagoda.name,
      remoteMyanmar: pagoda.nameMyanmar,
    );
    final metadata = [
      pagoda.category,
      if (pagoda.yearBuilt != null) pagoda.yearBuilt.toString(),
    ].where((value) => value.isNotEmpty).join('  •  ');

    return Align(
      alignment: Alignment.bottomCenter,
      child: ResponsiveContent(
        child: Container(
          margin: EdgeInsets.fromLTRB(
            Responsive.spacing(context),
            0,
            Responsive.spacing(context),
            Responsive.spacing(context),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF3),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCCCB3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 104,
                    child: PagodaImageWidget(
                      imageUrl: pagoda.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: const ColoredBox(
                        color: Color(0xFFF0E4CE),
                        child: Icon(
                          Icons.temple_buddhist_rounded,
                          color: Color(0xFFA34A2A),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  metadata,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFA34A2A),
                                    letterSpacing: 0.65,
                                  ),
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: context.l10n.translate(
                                  'map.clearSelection',
                                ),
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    setState(() => _selectedPagoda = null);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                19,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.pagodaDescription(
                              pagoda.id,
                              pagoda.description,
                              remoteMyanmar: pagoda.descriptionMyanmar,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF786A5D),
                              height: 1.3,
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
                                padding: const EdgeInsets.only(top: 7),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_boat_outlined,
                                      size: 16,
                                      color: Color(0xFF166B91),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        context.l10n.translate(
                                          'route.riverCrossingLocation',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: const Color(0xFF166B91),
                                              letterSpacing: 0.25,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PagodaDetailScreen(pagoda: pagoda),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.menu_book_outlined, size: 18),
                              label: Text(
                                context.l10n.translate('map.viewDetails'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
        if (_mode == MapTripMode.path && _shortestPathRoute.isNotEmpty) ...[
          FloatingActionButton.small(
            heroTag: 'focus-shortest-path',
            onPressed: () => _focusRoute(_shortestPathRoute),
            child: const Icon(Icons.alt_route),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
        ],
        if ((_selectedPagoda != null || _selectedTravelPlace != null) &&
            (_mode == MapTripMode.browse ||
                (_mode == MapTripMode.trips && _selectedTrip != null))) ...[
          FloatingActionButton.small(
            heroTag: 'selected-pagoda',
            onPressed: () {
              final selectedPagoda = _selectedPagoda;
              final selectedTravelPlace = _selectedTravelPlace;
              if (selectedPagoda == null && selectedTravelPlace == null) return;
              _mapController.move(
                LatLng(
                  selectedPagoda?.latitude ?? selectedTravelPlace!.latitude,
                  selectedPagoda?.longitude ?? selectedTravelPlace!.longitude,
                ),
                AppConstants.defaultZoom + 2,
              );
            },
            child: const Icon(Icons.place),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
        ],
        _buildLocateButton(),
      ],
    );
  }

  Widget _buildLocateButton() {
    return Material(
      elevation: 3,
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _isLocating ? null : _goToUserLocation,
        onLongPress: _resetToBaganOverview,
        child: Tooltip(
          message: context.l10n.translate('map.locateMe'),
          child: Semantics(
            button: true,
            label: context.l10n.translate('map.locateMe'),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: _isLocating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(
                        Icons.my_location,
                        color: _userLocation == null
                            ? const Color(0xFF5C534C)
                            : const Color(0xFF1D4E89),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildUserLocationMarker(LatLng point) {
    return Marker(
      point: point,
      width: 56,
      height: 56,
      alignment: Alignment.center,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = 0.35 + (_pulseController.value * 0.45);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 28 + (18 * _pulseController.value),
                  height: 28 + (18 * _pulseController.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1D4E89).withValues(alpha: 0.18 * pulse),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1D4E89),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
