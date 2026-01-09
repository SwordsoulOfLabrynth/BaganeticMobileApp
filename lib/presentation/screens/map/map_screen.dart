import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Pagoda? _selectedPagoda;

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
          
          final pagodas = provider.pagodas;
          
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedPagoda?.id == pagoda.id
                                  ? const Color(0xFFD4AF37)
                                  : const Color(0xFF8B4513),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.temple_buddhist,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (_selectedPagoda != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildPagodaInfo(_selectedPagoda!),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
                // Navigate to pagoda detail
              },
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
}
