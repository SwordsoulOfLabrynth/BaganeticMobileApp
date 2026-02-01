import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_route_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
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

  void _setMode(MapTripMode mode) {
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

    final route = await OfflineRouteService.instance.buildRouteForPoints(points);
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
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _selectTrip(Trip trip) {
    if (_selectedTrip?.id == trip.id) return;
    setState(() {
      _selectedTrip = trip;
    });
    _loadTripRoute(trip);
  }

  void _openCreateTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(
          initialPagoda: _selectedPagoda,
        ),
      ),
    );
  }

  void _openTripDetail(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailScreen(trip: trip),
      ),
    );
  }

  Future<void> _openEditTrip(Trip trip) async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('map.title')),
        elevation: 0,
      ),
      body: Consumer2<PagodaProvider, TripProvider>(
        builder: (context, pagodaProvider, tripProvider, _) {
          if (pagodaProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

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
                    tileProvider: const FMTCStore(AppConstants.mapTileStore)
                        .getTileProvider(),
                  ),
                  if (showTrip && _tripRoute.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _tripRoute,
                          color: const Color(0xFFD4AF37),
                          strokeWidth: 5,
                          borderStrokeWidth: 3,
                          borderColor: Colors.black.withOpacity(0.25),
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
                child: SafeArea(
                  child: _buildModeToggle(context),
                ),
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
                        color: Colors.black.withOpacity(0.55),
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
                  child: _buildTripPanel(tripProvider),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = MapTripMode.values.map((mode) => _mode == mode).toList();
    final l10n = context.l10n;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.95),
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(18),
        selectedColor: Colors.white,
        color: theme.colorScheme.primary,
        fillColor: theme.colorScheme.primary,
        borderColor: Colors.transparent,
        selectedBorderColor: Colors.transparent,
        constraints: const BoxConstraints(minHeight: 40, minWidth: 120),
        isSelected: isSelected,
        onPressed: (index) => _setMode(MapTripMode.values[index]),
        children: [
          _ModeChip(label: l10n.translate('map.mode.browse'), icon: Icons.map_outlined),
          _ModeChip(label: l10n.translate('map.mode.trips'), icon: Icons.route),
        ],
      ),
    );
  }

  Widget _buildTripPanel(TripProvider provider) {
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
              color: Colors.black.withOpacity(0.15),
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
                        TextButton.icon(
                          onPressed: _openCreateTrip,
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.translate('common.create')),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      helper,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_selectedTrip != null)
                    _buildSelectedTripSummary(_selectedTrip!),
                ],
              ),
            ),
            ..._buildTripListSlivers(provider),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTripListSlivers(TripProvider provider) {
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
          child: _buildEmptyTrips(),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
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
                  selectedTileColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD4AF37),
                    child: Text('${trip.stops.length}'),
                  ),
                  title: Text(trip.name),
                  subtitle: Text(
                    '${Helpers.formatDate(trip.date)} - ${context.l10n.translate('common.stopsCount', args: {'count': trip.stops.length.toString()})}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTrip(trip),
                ),
              );
            },
            childCount: trips.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyTrips() {
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
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
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
            Row(
              children: [
                _buildTripStat(
                  Icons.place,
                  context.l10n.translate(
                    'common.stopsCount',
                    args: {'count': trip.stops.length.toString()},
                  ),
                ),
                const SizedBox(width: 12),
                _buildTripStat(
                  Icons.straighten,
                  Helpers.formatDistance(
                    context,
                    trip.getTotalDistance(),
                  ),
                ),
                const SizedBox(width: 12),
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
        Text(
          label,
          style: TextStyle(color: Colors.grey[700]),
        ),
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                      fontSize: 20,
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
            const SizedBox(height: 8),
            Text(
              context.l10n.pagodaDescription(pagoda.id, pagoda.description),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PagodaDetailScreen(pagoda: pagoda),
                  ),
                );
              },
              child: Text(context.l10n.translate('map.viewDetails')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mode == MapTripMode.trips) ...[
          FloatingActionButton.small(
            heroTag: 'create-trip',
            onPressed: _openCreateTrip,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'reset-map',
          onPressed: () {
            _mapController.move(
              LatLng(
                AppConstants.baganLatitude,
                AppConstants.baganLongitude,
              ),
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
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final bool isSelected;
  final Animation<double> pulse;

  const _MapMarker({
    required this.isSelected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF8B4513),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.temple_buddhist,
        color: Colors.white,
        size: 20,
      ),
    );

    if (!isSelected) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.4).animate(
            CurvedAnimation(parent: pulse, curve: Curves.easeOut),
          ),
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
