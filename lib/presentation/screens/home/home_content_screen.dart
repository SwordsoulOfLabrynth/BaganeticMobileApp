import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import '../../../data/models/pagoda_model.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';

class HomeContentScreen extends StatelessWidget {
  static const List<String> _curatedFeaturedIds = [
    'ananda',
    'shwezigon',
    'dhammayangyi',
  ];

  final void Function(int) onNavigateToTab;

  const HomeContentScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pagePadding = Responsive.pagePadding(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomReservedSpace =
        (Responsive.isTabletOrLarger(context) ? 96.0 : 136.0) + bottomInset;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('app.title')), elevation: 0),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: pagePadding.copyWith(
            bottom: pagePadding.bottom + bottomReservedSpace,
          ),
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
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final l10n = context.l10n;
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
              const Icon(Icons.temple_buddhist, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('home.welcomeTitle'),
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
            l10n.translate('home.welcomeBody'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPagodas(BuildContext context) {
    final l10n = context.l10n;
    const sectionSpacing = 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('home.featuredTitle'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Consumer<PagodaProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final featuredPagodas = _resolveFeaturedPagodas(
              provider.allPagodas,
            );

            if (featuredPagodas.isEmpty) {
              return Center(child: Text(l10n.translate('home.featuredEmpty')));
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final showGrid = constraints.maxWidth >= 620;

                if (!showGrid) {
                  final cardWidth = constraints.maxWidth < 380 ? 150.0 : 170.0;

                  return SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: featuredPagodas.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: sectionSpacing),
                      itemBuilder: (context, index) => SizedBox(
                        width: cardWidth,
                        child: _buildFeaturedPagodaCard(
                          context,
                          featuredPagodas[index],
                        ),
                      ),
                    ),
                  );
                }

                final columnCount = _bestColumnCount(
                  maxWidth: constraints.maxWidth,
                  itemCount: featuredPagodas.length,
                  minCardWidth: Responsive.isDesktopOrLarger(context)
                      ? 240
                      : 220,
                );
                final cardWidth =
                    (constraints.maxWidth -
                        (sectionSpacing * (columnCount - 1))) /
                    columnCount;

                return Wrap(
                  spacing: sectionSpacing,
                  runSpacing: sectionSpacing,
                  children: featuredPagodas
                      .map(
                        (pagoda) => SizedBox(
                          width: cardWidth,
                          child: _buildFeaturedPagodaCard(
                            context,
                            pagoda,
                            imageHeight: Responsive.isDesktopOrLarger(context)
                                ? 156
                                : 140,
                            titleMaxLines: 2,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  List<Pagoda> _resolveFeaturedPagodas(List<Pagoda> allPagodas) {
    if (allPagodas.isEmpty) {
      return const <Pagoda>[];
    }

    final byId = <String, Pagoda>{for (final p in allPagodas) p.id: p};
    final curated = _curatedFeaturedIds
        .map((id) => byId[id])
        .whereType<Pagoda>()
        .toList();

    if (curated.length >= 3) {
      return curated.take(3).toList();
    }

    final remaining =
        allPagodas.where((p) => !curated.any((c) => c.id == p.id)).toList()
          ..shuffle();

    return [...curated, ...remaining].take(3).toList();
  }

  Widget _buildFeaturedPagodaCard(
    BuildContext context,
    Pagoda pagoda, {
    double imageHeight = 100,
    int titleMaxLines = 1,
  }) {
    final l10n = context.l10n;
    return Card(
      elevation: 4,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: PagodaImageWidget(
                imageUrl: pagoda.imageUrl,
                height: imageHeight,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pagodaName(pagoda.id, pagoda.name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.categoryLabel(pagoda.category),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final l10n = context.l10n;
    const sectionSpacing = 16.0;
    final actions = [
      _QuickActionItem(
        title: l10n.translate('home.actionExplore'),
        icon: Icons.temple_buddhist,
        onTap: () => onNavigateToTab(1),
      ),
      _QuickActionItem(
        title: l10n.translate('home.actionProfile'),
        icon: Icons.person,
        onTap: () => onNavigateToTab(4),
      ),
      _QuickActionItem(
        title: l10n.translate('home.actionMap'),
        icon: Icons.map,
        onTap: () => onNavigateToTab(2),
      ),
      _QuickActionItem(
        title: l10n.translate('home.actionCommunity'),
        icon: Icons.forum_outlined,
        onTap: () => onNavigateToTab(3),
      ),
      _QuickActionItem(
        title: l10n.translate('chat.title'),
        icon: Icons.support_agent_outlined,
        onTap: () => AIAssistantLauncher.open(
          context,
          entryContext: const AIEntryContext.global(),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('home.quickActions'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = _bestColumnCount(
              maxWidth: constraints.maxWidth,
              itemCount: actions.length,
              minCardWidth: Responsive.isCompact(context) ? 150 : 190,
              minColumns: 2,
            );
            final cardWidth =
                (constraints.maxWidth - (sectionSpacing * (columnCount - 1))) /
                columnCount;

            return Wrap(
              spacing: sectionSpacing,
              runSpacing: sectionSpacing,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: cardWidth,
                      child: _buildQuickActionCard(
                        context,
                        action.title,
                        action.icon,
                        action.onTap,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final cardHeight = Responsive.isTabletOrLarger(context) ? 128.0 : 112.0;

    return SizedBox(
      height: cardHeight,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: const Color(0xFFD4AF37)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _bestColumnCount({
    required double maxWidth,
    required int itemCount,
    required double minCardWidth,
    int minColumns = 1,
  }) {
    if (itemCount <= minColumns) {
      return itemCount;
    }

    const spacing = 16.0;
    var bestCount = minColumns;

    for (var columns = minColumns; columns <= itemCount; columns++) {
      final cardWidth = (maxWidth - (spacing * (columns - 1))) / columns;
      if (cardWidth >= minCardWidth) {
        bestCount = columns;
      }
    }

    if (bestCount > 2 && itemCount % bestCount == 1) {
      final adjustedCount = bestCount - 1;
      final adjustedCardWidth =
          (maxWidth - (spacing * (adjustedCount - 1))) / adjustedCount;
      if (adjustedCardWidth >= minCardWidth) {
        return adjustedCount;
      }
    }

    return bestCount;
  }
}

class _QuickActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}
