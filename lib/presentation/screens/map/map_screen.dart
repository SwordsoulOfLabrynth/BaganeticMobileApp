import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_route_service.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
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

enum MapTripMode { browse, trips }

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
  bool _isRouteLoading = false;
  bool _isRouteFallback = false;
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
        featureName: context.l10n.translate('map.tripsTitle'),
      );
      if (!canContinue || !mounted) {
        return;
      }
    }
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
    });
    if (_mode != MapTripMode.browse && _selectedTrip != null) {
      _loadTripRoute(_selectedTrip!);
    }
  }

  Future<void> _loadTripRoute(Trip trip) async {
    final points = trip.stops
        .map((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();
    if (points.isEmpty) {
      setState(() {
        _tripRoute = [];
        _isRouteFallback = false;
        _isRouteLoading = false;
      });
      return;
    }

    setState(() {
      _tripRoute = points;
      _isRouteFallback = false;
      _isRouteLoading = true;
    });

    final route = await OfflineRouteService.instance.buildRouteForPoints(
      points,
    );
    if (!mounted) return;

    final resolved = route.isEmpty ? points : route;
    setState(() {
      _tripRoute = resolved;
      _isRouteFallback = route.isEmpty;
      _isRouteLoading = false;
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

  void _selectTrip(Trip trip) {
    if (_selectedTrip?.id == trip.id) return;
    setState(() {
      _selectedTrip = trip;
    });
    _loadTripRoute(trip);
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
    );
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
        _isRouteFallback = false;
        _isRouteLoading = false;
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
          final showTrip = _mode != MapTripMode.browse && _selectedTrip != null;
          final markers = showTrip && _selectedTrip != null
              ? _buildTripMarkers(_selectedTrip!)
              : _buildPagodaMarkers(pagodas);

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
                    userAgentPackageName: 'com.baganetic.app',
                    tileProvider: FMTCTileProvider(
                      stores: const {
                        AppConstants.mapTileStore:
                            BrowseStoreStrategy.readUpdateCreate,
                      },
                    ),
                  ),
                  if (showTrip && _tripRoute.isNotEmpty)
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
              if (_mode == MapTripMode.browse && _selectedPagoda != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: _buildPagodaInfo(_selectedPagoda!),
                  ),
                ),
              if (showTrip && _isRouteFallback)
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
              if (_mode != MapTripMode.browse)
                Positioned.fill(
                  child: _buildTripPanel(tripProvider, isLoggedIn: isLoggedIn),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButtons(isLoggedIn: isLoggedIn),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = MapTripMode.values.map((mode) => _mode == mode).toList();
    final l10n = context.l10n;
    final availableWidth = MediaQuery.sizeOf(context).width - 32;
    final tabMinWidth = (availableWidth / 2).clamp(96, 170).toDouble();
    final isCompact = Responsive.isCompact(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.95),
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(18),
        selectedColor: Colors.white,
        color: theme.colorScheme.primary,
        fillColor: theme.colorScheme.primary,
        borderColor: Colors.transparent,
        selectedBorderColor: Colors.transparent,
        constraints: BoxConstraints(
          minHeight: isCompact ? 36 : 40,
          minWidth: tabMinWidth,
        ),
        isSelected: isSelected,
        onPressed: (index) => _setMode(MapTripMode.values[index]),
        children: [
          _ModeChip(
            label: l10n.translate('map.mode.browse'),
            icon: Icons.map_outlined,
          ),
          _ModeChip(label: l10n.translate('map.mode.trips'), icon: Icons.route),
        ],
      ),
    );
  }

  Widget _buildTripPanel(TripProvider provider, {required bool isLoggedIn}) {
    final label = context.l10n.translate('map.tripsTitle');
    final helper = context.l10n.translate('map.tripsHelp');

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
                        if (_isRouteLoading)
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
                      _isRouteFallback = false;
                    });
                  },
                ),
              ],
            ),
            Text(
              Helpers.formatDate(trip.date),
              style: TextStyle(color: Colors.grey[700]),
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
                  Icons.access_time,
                  '${trip.getEstimatedDuration()} ${context.l10n.translate('common.minutesShort')}',
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
          onTap: () {
            setState(() {
              _selectedPagoda = pagoda;
            });
          },
          child: _MapMarker(
            isSelected: _selectedPagoda?.id == pagoda.id,
            pulse: _pulseController,
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildTripMarkers(Trip trip) {
    return trip.stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      final color = index == 0
          ? Colors.green
          : index == trip.stops.length - 1
          ? Colors.red
          : const Color(0xFFD4AF37);

      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                        context.l10n.pagodaName(pagoda.id, pagoda.name),
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
                  context.l10n.pagodaDescription(pagoda.id, pagoda.description),
                  maxLines: Responsive.isDesktopOrLarger(context) ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: Responsive.responsiveFontSize(context, 14),
                  ),
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
        if (_selectedPagoda != null && _mode == MapTripMode.browse) ...[
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

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ModeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: Responsive.responsiveFontSize(context, 14),
            ),
          ),
        ],
      ),
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
