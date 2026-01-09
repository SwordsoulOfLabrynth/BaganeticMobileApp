import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../../data/models/trip_model.dart';
import 'trip_detail_screen.dart';
import 'create_trip_screen.dart';
import '../../../core/utils/helpers.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        elevation: 0,
      ),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final trips = provider.trips;
          
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No trips yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first trip itinerary',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateTripScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Trip'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              return _buildTripCard(context, trips[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTripScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Trip'),
      ),
    );
  }
  
  Widget _buildTripCard(BuildContext context, Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailScreen(trip: trip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Trip'),
                          content: const Text('Are you sure you want to delete this trip?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true && context.mounted) {
                        await context.read<TripProvider>().deleteTrip(trip.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatDate(trip.date),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${trip.stops.length} stops',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              if (trip.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  trip.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    Icons.straighten,
                    Helpers.formatDistance(trip.getTotalDistance()),
                  ),
                  _buildInfoChip(
                    Icons.access_time,
                    '${trip.getEstimatedDuration()} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
    );
  }
}
