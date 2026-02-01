import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/pagoda_model.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../../../core/localization/app_localizations.dart';

class PagodasListScreen extends StatelessWidget {
  const PagodasListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('pagodas.title')),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildCategoryFilter(context),
          Expanded(
            child: Consumer<PagodaProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final pagodas = provider.pagodas;
                
                if (pagodas.isEmpty) {
                  return Center(
                    child: Text(l10n.translate('pagodas.empty')),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pagodas.length,
                  itemBuilder: (context, index) {
                    return _buildPagodaCard(context, pagodas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: l10n.translate('pagodas.searchHint'),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          context.read<PagodaProvider>().setSearchQuery(value);
        },
      ),
    );
  }
  
  Widget _buildCategoryFilter(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PagodaProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AppConstants.categories.length,
            itemBuilder: (context, index) {
              final category = AppConstants.categories[index];
              final isSelected = provider.selectedCategory == category;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(l10n.categoryLabel(category)),
                  selected: isSelected,
                  onSelected: (_) {
                    provider.setCategory(category);
                  },
                  selectedColor: const Color(0xFFB8860B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildPagodaCard(BuildContext context, Pagoda pagoda) {
    final l10n = context.l10n;
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
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.pagodaName(pagoda.id, pagoda.name),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          pagoda.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: pagoda.isFavorite ? Colors.red : null,
                        ),
                        onPressed: () {
                          context.read<PagodaProvider>().toggleFavorite(pagoda.id);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8860B).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB8860B), width: 1),
                    ),
                    child: Text(
                      l10n.categoryLabel(pagoda.category),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pagodaDescription(pagoda.id, pagoda.description),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
