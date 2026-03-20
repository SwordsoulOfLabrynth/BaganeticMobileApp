import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/auth_gate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../../data/models/trip_model.dart';
import 'trip_detail_screen.dart';
import 'create_trip_screen.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/sign_in_required_view.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoggedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.translate('trips.title')),
          elevation: 0,
        ),
        body: SignInRequiredView(
          icon: Icons.route,
          message: l10n.translate('trips.signInPrompt'),
          onSignIn: () {
            AuthGate.openSignIn(context);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('trips.title')), elevation: 0),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = provider.trips;

          if (trips.isEmpty) {
            return ResponsiveContent(
              child: Center(
                child: Padding(
                  padding: Responsive.pagePadding(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 100, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('trips.emptyTitle'),
                        style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('trips.emptySubtitle'),
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
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
                        label: Text(l10n.translate('trips.createTrip')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ResponsiveContent(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 900;
                final crossAxisCount = constraints.maxWidth >= 1200 ? 3 : 2;

                if (!useGrid) {
                  return ListView.builder(
                    padding: Responsive.pagePadding(context),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      return _buildTripCard(context, trips[index]);
                    },
                  );
                }

                return GridView.builder(
                  padding: Responsive.pagePadding(context),
                  itemCount: trips.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    return _buildTripCard(context, trips[index]);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateTripScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('trips.createTrip')),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final l10n = context.l10n;
    final isWideLayout = MediaQuery.sizeOf(context).width >= 900;
    return Card(
      margin: isWideLayout
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateTripScreen(existingTrip: trip),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.translate('trips.deleteTitle')),
                          content: Text(l10n.translate('trips.deleteConfirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.translate('common.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                l10n.translate('common.delete'),
                                style: const TextStyle(color: Colors.red),
                              ),
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
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Helpers.formatDate(trip.date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.translate(
                          'common.stopsCount',
                          args: {'count': trip.stops.length.toString()},
                        ),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
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
                    Helpers.formatDistance(context, trip.getTotalDistance()),
                  ),
                  _buildInfoChip(
                    Icons.access_time,
                    '${trip.getEstimatedDuration()} ${l10n.translate('common.minutesShort')}',
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
      backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
    );
  }
}
