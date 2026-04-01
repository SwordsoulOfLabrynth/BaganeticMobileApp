import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import '../../providers/pagoda_provider.dart';
import '../../../core/utils/auth_gate.dart';
import '../trips/create_trip_screen.dart';
import '../home/home_screen.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';

class PagodaDetailScreen extends StatefulWidget {
  final Pagoda pagoda;

  const PagodaDetailScreen({super.key, required this.pagoda});

  @override
  State<PagodaDetailScreen> createState() => _PagodaDetailScreenState();
}

class _PagodaDetailScreenState extends State<PagodaDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  List<String> _buildImageList(Pagoda pagoda) {
    final List<String> images = [];
    if (pagoda.imageUrl.trim().isNotEmpty) {
      images.add(pagoda.imageUrl);
    }
    for (final image in pagoda.images) {
      if (image.trim().isNotEmpty && !images.contains(image)) {
        images.add(image);
      }
    }
    return images;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pagoda = widget.pagoda;
    final pagodaProvider = context.watch<PagodaProvider>();
    final livePagoda = pagodaProvider.allPagodas.firstWhere(
      (item) => item.id == pagoda.id,
      orElse: () => pagoda,
    );
    final isFavorite = livePagoda.isFavorite;
    final images = _buildImageList(pagoda);
    final pagodaName = l10n.pagodaName(pagoda.id, pagoda.name);
    final pagodaDescription = l10n.pagodaDescription(
      pagoda.id,
      pagoda.description,
    );
    final pagodaHistory = pagoda.historicalInfo == null
        ? null
        : l10n.pagodaHistory(pagoda.id, pagoda.historicalInfo!);
    final pagodaArchitecture = pagoda.architecturalStyle == null
        ? null
        : l10n.pagodaArchitecture(pagoda.id, pagoda.architecturalStyle!);
    final pagodaLegends = pagoda.legends == null
        ? null
        : l10n.pagodaLegends(pagoda.id, pagoda.legends!);
    final pagodaReligious = pagoda.religiousImportance == null
        ? null
        : l10n.pagodaReligiousImportance(
            pagoda.id,
            pagoda.religiousImportance!,
          );
    final pagodaPreservation = pagoda.preservationInfo == null
        ? null
        : l10n.pagodaPreservation(pagoda.id, pagoda.preservationInfo!);
    final pagodaBestTime = pagoda.bestTimeToVisit == null
        ? null
        : l10n.pagodaBestTime(pagoda.id, pagoda.bestTimeToVisit!);
    final pagodaVisitorLocation = pagoda.visitorLocation == null
        ? null
        : l10n.pagodaVisitorLocation(pagoda.id, pagoda.visitorLocation!);
    final pagodaOpeningHours = pagoda.openingHours == null
        ? null
        : l10n.pagodaOpeningHours(pagoda.id, pagoda.openingHours!);
    final pagodaDressCode = pagoda.dressCode == null
        ? null
        : l10n.pagodaDressCode(pagoda.id, pagoda.dressCode!);
    final pagodaEntranceFee = pagoda.entranceFee == null
        ? null
        : l10n.pagodaEntranceFee(pagoda.id, pagoda.entranceFee!);
    final pagodaPhotographyRules = pagoda.photographyRules == null
        ? null
        : l10n.pagodaPhotographyRules(pagoda.id, pagoda.photographyRules!);
    final pagodaFinalWords = pagoda.finalWords == null
        ? null
        : l10n.pagodaFinalWords(pagoda.id, pagoda.finalWords!);
    final uniqueFeatures = pagoda.uniqueFeatures;
    final localizedUniqueFeatures = uniqueFeatures
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final feature = entry.value;
          return PagodaFeature(
            title: l10n.pagodaUniqueFeatureTitle(
              pagoda.id,
              index,
              feature.title,
            ),
            description: l10n.pagodaUniqueFeatureDescription(
              pagoda.id,
              index,
              feature.description,
            ),
            icon: feature.icon,
            imageUrl: feature.imageUrl,
          );
        })
        .toList(growable: false);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: Responsive.isDesktopOrLarger(context) ? 400 : 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pagodaName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.responsiveFontSize(context, 20),
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.length <= 1)
                    PagodaImageWidget(
                      imageUrl: images.isNotEmpty ? images.first : '',
                      fit: BoxFit.cover,
                      height: 320,
                      width: double.infinity,
                      placeholder: Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.temple_buddhist, size: 100),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return PagodaImageWidget(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          height: Responsive.isDesktopOrLarger(context)
                              ? 400
                              : 320,
                          width: double.infinity,
                          placeholder: Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.temple_buddhist, size: 100),
                          ),
                        );
                      },
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x7A000000)],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 8,
                      bottom: 10,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_left,
                        onTap: () {
                          if (_currentImageIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 10,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_right,
                        onTap: () {
                          if (_currentImageIndex < images.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  if (images.length > 1)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            images.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: index == _currentImageIndex ? 18 : 6,
                              decoration: BoxDecoration(
                                color: index == _currentImageIndex
                                    ? Colors.white
                                    : Colors.white70,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => AIAssistantLauncher.open(
                  context,
                  entryContext: AIEntryContext.pagoda(pagoda.id),
                ),
                icon: const Icon(Icons.support_agent_outlined),
                tooltip: l10n.translate('chat.fabLabel'),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () async {
                  final canContinue = await AuthGate.ensureSignedIn(
                    context,
                    featureName: l10n.translate('profile.favorites'),
                  );
                  if (!canContinue || !context.mounted) {
                    return;
                  }
                  context.read<PagodaProvider>().toggleFavorite(pagoda.id);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: ResponsiveContent(
              child: Padding(
                padding: Responsive.pagePadding(context).copyWith(
                  top: Responsive.spacing(context),
                  bottom: Responsive.largeSpacing(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Responsive.smallSpacing(context),
                      runSpacing: Responsive.smallSpacing(context),
                      children: [
                        Chip(
                          label: Text(l10n.categoryLabel(pagoda.category)),
                          backgroundColor: const Color(0xFFD4AF37),
                          labelStyle: const TextStyle(color: Colors.white),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Chip(
                          label: Text(
                            '${pagoda.latitude.toStringAsFixed(4)}, ${pagoda.longitude.toStringAsFixed(4)}',
                          ),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          avatar: Icon(
                            Icons.location_on,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (Responsive.isDesktopOrLarger(context))
                      _buildDesktopStats(context, pagoda)
                    else
                      _buildMobileStats(context, pagoda),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.overview'),
                      child: Text(
                        pagodaDescription,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.quickFacts'),
                      child: Column(
                        children: [
                          if (pagodaArchitecture != null)
                            _InfoTile(
                              icon: Icons.architecture,
                              label: l10n.translate('pagoda.detail.archStyle'),
                              value: pagodaArchitecture,
                            ),
                          if (pagoda.height != null)
                            _InfoTile(
                              icon: Icons.height,
                              label: l10n.translate('pagoda.detail.height'),
                              value: pagoda.height!,
                            ),
                          if (pagoda.yearBuilt != null)
                            _InfoTile(
                              icon: Icons.event,
                              label: l10n.translate('pagoda.detail.yearBuilt'),
                              value: pagoda.yearBuilt.toString(),
                            ),
                          _InfoTile(
                            icon: Icons.place,
                            label: l10n.translate('pagoda.detail.location'),
                            value:
                                '${pagoda.latitude.toStringAsFixed(4)}, ${pagoda.longitude.toStringAsFixed(4)}',
                          ),
                        ],
                      ),
                    ),
                    if (pagodaHistory != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.historicalInfo'),
                        child: Text(
                          pagodaHistory,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                    if (pagodaLegends != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.legends'),
                        child: Text(
                          pagodaLegends,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                    if (pagodaReligious != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate(
                          'pagoda.detail.religiousImportance',
                        ),
                        child: Text(
                          pagodaReligious,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                    if (pagodaPreservation != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.preservation'),
                        child: Text(
                          pagodaPreservation,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                    if (localizedUniqueFeatures.isNotEmpty) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.uniqueFeatures'),
                        child: Column(
                          children: localizedUniqueFeatures
                              .map((feature) => _FeatureTile(feature: feature))
                              .toList(),
                        ),
                      ),
                    ],
                    if (pagodaVisitorLocation != null ||
                        pagodaOpeningHours != null ||
                        pagodaDressCode != null ||
                        pagodaEntranceFee != null ||
                        pagodaPhotographyRules != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.visitorInfo'),
                        child: Column(
                          children: [
                            if (pagodaVisitorLocation != null)
                              _InfoTile(
                                icon: Icons.location_on,
                                label: l10n.translate('pagoda.detail.location'),
                                value: pagodaVisitorLocation,
                              ),
                            if (pagodaOpeningHours != null)
                              _InfoTile(
                                icon: Icons.access_time,
                                label: l10n.translate(
                                  'pagoda.detail.openingHours',
                                ),
                                value: pagodaOpeningHours,
                              ),
                            if (pagodaDressCode != null)
                              _InfoTile(
                                icon: Icons.checkroom,
                                label: l10n.translate(
                                  'pagoda.detail.dressCode',
                                ),
                                value: pagodaDressCode,
                              ),
                            if (pagodaEntranceFee != null)
                              _InfoTile(
                                icon: Icons.confirmation_number,
                                label: l10n.translate(
                                  'pagoda.detail.entranceFee',
                                ),
                                value: pagodaEntranceFee,
                              ),
                            if (pagodaPhotographyRules != null)
                              _InfoTile(
                                icon: Icons.photo_camera,
                                label: l10n.translate(
                                  'pagoda.detail.photography',
                                ),
                                value: pagodaPhotographyRules,
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (pagodaBestTime != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.bestTimeToVisit'),
                        child: Text(
                          pagodaBestTime,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                    if (pagodaFinalWords != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _SectionCard(
                        title: l10n.translate('pagoda.detail.finalWords'),
                        child: Text(
                          pagodaFinalWords,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: Responsive.largeSpacing(context)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final canContinue = await AuthGate.ensureSignedIn(
                            context,
                            featureName: l10n.translate('trips.title'),
                          );
                          if (!canContinue || !context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CreateTripScreen(initialPagoda: pagoda),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_road),
                        label: Text(l10n.translate('pagoda.detail.addToTrip')),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.isCompact(context) ? 16 : 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.smallSpacing(context)),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeScreen(
                                initialIndex: 2,
                                initialMapPagoda: pagoda,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: Text(l10n.translate('pagoda.detail.viewOnMap')),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.isCompact(context) ? 16 : 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 26),
          onPressed: onTap,
          tooltip: context.l10n.translate('pagoda.detail.changeImage'),
        ),
      ),
    );
  }
}

Widget _buildDesktopStats(BuildContext context, Pagoda pagoda) {
  final l10n = context.l10n;
  return Row(
    children: [
      Expanded(
        child: _StatTile(
          label: l10n.translate('pagoda.detail.category'),
          value: l10n.categoryLabel(pagoda.category),
          icon: Icons.category,
        ),
      ),
      SizedBox(width: Responsive.spacing(context)),
      Expanded(
        child: _StatTile(
          label: l10n.translate('pagoda.detail.year'),
          value:
              pagoda.yearBuilt?.toString() ?? l10n.translate('common.unknown'),
          icon: Icons.event,
        ),
      ),
      SizedBox(width: Responsive.spacing(context)),
      Expanded(
        child: _StatTile(
          label: l10n.translate('pagoda.detail.age'),
          value: pagoda.yearBuilt == null
              ? l10n.translate('common.unknown')
              : '${DateTime.now().year - pagoda.yearBuilt!} ${l10n.translate('common.yearsShort')}',
          icon: Icons.history,
        ),
      ),
    ],
  );
}

Widget _buildMobileStats(BuildContext context, Pagoda pagoda) {
  final l10n = context.l10n;
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              label: l10n.translate('pagoda.detail.category'),
              value: l10n.categoryLabel(pagoda.category),
              icon: Icons.category,
            ),
          ),
          SizedBox(width: Responsive.smallSpacing(context)),
          Expanded(
            child: _StatTile(
              label: l10n.translate('pagoda.detail.year'),
              value:
                  pagoda.yearBuilt?.toString() ??
                  l10n.translate('common.unknown'),
              icon: Icons.event,
            ),
          ),
        ],
      ),
      SizedBox(height: Responsive.smallSpacing(context)),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              label: l10n.translate('pagoda.detail.age'),
              value: pagoda.yearBuilt == null
                  ? l10n.translate('common.unknown')
                  : '${DateTime.now().year - pagoda.yearBuilt!} ${l10n.translate('common.yearsShort')}',
              icon: Icons.history,
            ),
          ),
        ],
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final PagodaFeature feature;

  const _FeatureTile({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feature.icon != null && feature.icon!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Text(feature.icon!, style: const TextStyle(fontSize: 20)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (feature.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(feature.description),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
