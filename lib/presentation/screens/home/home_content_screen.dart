import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../../widgets/pagoda_image_widget.dart';

class HomeContentScreen extends StatelessWidget {
  final void Function(int) onNavigateToTab;

  const HomeContentScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baganetic'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 24),
            _buildFeaturedPagodas(context),
            const SizedBox(height: 24),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.temple_buddhist,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome to Baganetic',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explore the ancient wonders of Bagan. Discover pagodas, plan your trips, and create unforgettable memories.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPagodas(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Pagodas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Consumer<PagodaProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final featuredPagodas = provider.pagodas.take(3).toList();

            if (featuredPagodas.isEmpty) {
              return const Center(
                child: Text('No featured pagodas available'),
              );
            }

            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: featuredPagodas.length,
                itemBuilder: (context, index) {
                  return _buildFeaturedPagodaCard(context, featuredPagodas[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedPagodaCard(BuildContext context, Pagoda pagoda) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PagodaDetailScreen(pagoda: pagoda),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: PagodaImageWidget(
                  imageUrl: pagoda.imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pagoda.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pagoda.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                'Explore Pagodas',
                Icons.temple_buddhist,
                () {
                  onNavigateToTab(1);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard(
                context,
                'View Map',
                Icons.map,
                () {
                  onNavigateToTab(2);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                'Plan Trip',
                Icons.route,
                () {
                  onNavigateToTab(3);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard(
                context,
                'Profile',
                Icons.person,
                () {
                  onNavigateToTab(4);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
