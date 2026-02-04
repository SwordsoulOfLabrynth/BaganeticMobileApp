import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/pagoda_model.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';

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
      body: ResponsiveContent(
        child: Column(
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
                    return Center(child: Text(l10n.translate('pagodas.empty')));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = Responsive.crossAxisCount(
                        context,
                        maxCount: Responsive.isLarge(context) ? 4 : 3,
                        minCount: 1,
                        itemWidth: 320,
                      );
                      final useGrid = crossAxisCount > 1;

                      if (!useGrid) {
                        return ListView.builder(
                          padding: Responsive.pagePadding(context),
                          itemCount: pagodas.length,
                          itemBuilder: (context, index) {
                            return _buildPagodaCard(
                              context,
                              pagodas[index],
                              useGrid: false,
                            );
                          },
                        );
                      }

                      return GridView.builder(
                        padding: Responsive.pagePadding(context),
                        itemCount: pagodas.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: Responsive.spacing(context),
                          crossAxisSpacing: Responsive.spacing(context),
                          childAspectRatio: Responsive.isDesktopOrLarger(context) ? 0.75 : 0.82,
                        ),
                        itemBuilder: (context, index) {
                          return _buildPagodaCard(
                            context,
                            pagodas[index],
                            useGrid: true,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: Responsive.pagePadding(context).copyWith(bottom: 12),
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
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pagePadding(context).left,
            ),
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

  Widget _buildPagodaCard(
    BuildContext context,
    Pagoda pagoda, {
    required bool useGrid,
  }) {
    final l10n = context.l10n;
    final isWideLayout = Responsive.isTabletOrLarger(context);
    final isCompact = Responsive.isCompact(context);
    
    return Card(
      margin: isWideLayout
          ? EdgeInsets.zero
          : EdgeInsets.only(bottom: Responsive.spacing(context)),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            if (useGrid)
              Expanded(
                flex: isWideLayout ? 3 : 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: PagodaImageWidget(
                    imageUrl: pagoda.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: PagodaImageWidget(
                    imageUrl: pagoda.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (useGrid)
              Expanded(
                flex: 2,
                child: _buildCardDetails(context, pagoda, l10n, isCompact, true),
              )
            else
              _buildCardDetails(context, pagoda, l10n, isCompact, false),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetails(
    BuildContext context,
    Pagoda pagoda,
    AppLocalizations l10n,
    bool isCompact,
    bool allowDescriptionExpand,
  ) {
    return Padding(
      padding: Responsive.cardPadding(context).copyWith(
        top: Responsive.smallSpacing(context),
        bottom: Responsive.smallSpacing(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.pagodaName(pagoda.id, pagoda.name),
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  pagoda.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: pagoda.isFavorite ? Colors.red : null,
                  size: isCompact ? 20 : 24,
                ),
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  if (authProvider.user == null) {
                    Helpers.showSnackBar(
                      context,
                      l10n.translate('auth.loginRequired'),
                      isError: true,
                    );
                    return;
                  }
                  context.read<PagodaProvider>().toggleFavorite(pagoda.id);
                },
              ),
            ],
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.smallSpacing(context),
              vertical: Responsive.smallSpacing(context) * 0.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFB8860B).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFB8860B),
                width: 1,
              ),
            ),
            child: Text(
              l10n.categoryLabel(pagoda.category),
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: Responsive.smallSpacing(context)),
          if (allowDescriptionExpand)
            Expanded(
              child: Text(
                l10n.pagodaDescription(pagoda.id, pagoda.description),
                maxLines: isCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: Responsive.responsiveFontSize(context, 13),
                ),
              ),
            )
          else
            Text(
              l10n.pagodaDescription(pagoda.id, pagoda.description),
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: Responsive.responsiveFontSize(context, 13),
              ),
            ),
        ],
      ),
    );
  }
}
