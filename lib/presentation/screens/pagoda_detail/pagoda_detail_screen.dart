import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../providers/pagoda_provider.dart';
import '../../widgets/pagoda_image_widget.dart';

class PagodaDetailScreen extends StatelessWidget {
  final Pagoda pagoda;
  
  const PagodaDetailScreen({super.key, required this.pagoda});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pagoda.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 2),
                  ],
                ),
              ),
              background: PagodaImageWidget(
                imageUrl: pagoda.imageUrl,
                fit: BoxFit.cover,
                height: 300,
                width: double.infinity,
                placeholder: Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.temple_buddhist, size: 100),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  pagoda.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: pagoda.isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  context.read<PagodaProvider>().toggleFavorite(pagoda.id);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(pagoda.category),
                    backgroundColor: const Color(0xFFD4AF37),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pagoda.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  if (pagoda.historicalInfo != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Historical Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pagoda.historicalInfo!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (pagoda.architecturalStyle != null) ...[
                    const SizedBox(height: 24),
                    _buildInfoRow('Architectural Style', pagoda.architecturalStyle!),
                  ],
                  if (pagoda.yearBuilt != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Year Built', pagoda.yearBuilt.toString()),
                  ],
                  const SizedBox(height: 24),
                  _buildInfoRow(
                    'Location',
                    '${pagoda.latitude.toStringAsFixed(4)}, ${pagoda.longitude.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to map with this pagoda
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
