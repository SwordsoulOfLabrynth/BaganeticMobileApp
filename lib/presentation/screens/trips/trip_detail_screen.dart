import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/services/offline_route_service.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isExporting = false;
  late final Future<List<LatLng>> _routeFuture;

  @override
  void initState() {
    super.initState();
    final points = widget.trip.stops
        .map((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();
    _routeFuture = OfflineRouteService.instance.buildRouteForPoints(points);
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.trip.name),
          actions: [
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareTrip,
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportTrip,
              ),
            ],
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMap(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStats(),
                    const SizedBox(height: 24),
                    const Text(
                      'Itinerary',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildItinerary(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMap() {
    if (widget.trip.stops.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<LatLng>>(
      future: _routeFuture,
      builder: (context, snapshot) {
        final stopPoints = widget.trip.stops
            .map((stop) => LatLng(stop.latitude, stop.longitude))
            .toList();
        final isFallbackRoute = !snapshot.hasData || snapshot.data!.isEmpty;
        final routePoints = isFallbackRoute ? stopPoints : snapshot.data!;
        final bounds = LatLngBounds.fromPoints(routePoints);

        return SizedBox(
          height: 300,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(28),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.baganetic.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
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
                  MarkerLayer(
                    markers: widget.trip.stops.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stop = entry.value;

                      return Marker(
                        point: LatLng(stop.latitude, stop.longitude),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.green
                                : index == widget.trip.stops.length - 1
                                    ? Colors.red
                                    : const Color(0xFFD4AF37),
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
                    }).toList(),
                  ),
                ],
              ),
              if (isFallbackRoute)
                Positioned(
                  top: 12,
                  right: 12,
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
                      child: const Text(
                        'Using straight-line fallback route',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.trip.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              Helpers.formatDate(widget.trip.date),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        if (widget.trip.description != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.trip.description!,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ],
    );
  }
  
  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.location_on,
            label: 'Stops',
            value: '${widget.trip.stops.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.straighten,
            label: 'Distance',
            value: Helpers.formatDistance(widget.trip.getTotalDistance()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time,
            label: 'Duration',
            value: '${widget.trip.getEstimatedDuration()} min',
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildItinerary() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.trip.stops.length,
      itemBuilder: (context, index) {
        final stop = widget.trip.stops[index];
        final isLast = index == widget.trip.stops.length - 1;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Colors.green
                        : isLast
                            ? Colors.red
                            : const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
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
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.pagodaName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (stop.notes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          stop.notes!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                      if (stop.distanceToNext != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              Helpers.formatDistance(stop.distanceToNext!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _shareTrip() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });
    
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        throw Exception('Failed to capture screenshot');
      }
      
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/trip_${widget.trip.id}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);
      
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: '${widget.trip.name} - ${Helpers.formatDate(widget.trip.date)}',
      );
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error sharing trip: $e', isError: true);
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }
  
  Future<void> _exportTrip() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });
    
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        throw Exception('Failed to capture screenshot');
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/trip_${widget.trip.id}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);
      
      if (mounted) {
        Helpers.showSnackBar(context, 'Trip exported to: $imagePath');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error exporting trip: $e', isError: true);
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }
}
