import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../core/constants/app_constants.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final Pagoda? initialPagoda;

  const MapScreen({super.key, this.initialPagoda});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Pagoda? _selectedPagoda;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        elevation: 0,
      ),
      body: Consumer<PagodaProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final pagodas = provider.allPagodas;
          
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
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.baganetic.app',
                  ),
                  MarkerLayer(
                    markers: pagodas.map((pagoda) {
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
                    }).toList(),
                  ),
                ],
              ),
              if (pagodas.isEmpty)
                const Center(
                  child: Text(
                    'No pagodas available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              if (_selectedPagoda != null)
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
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedPagoda != null) ...[
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
      ),
    );
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
                    pagoda.name,
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
              pagoda.description,
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
              child: const Text('View Details'),
            ),
          ],
        ),
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
