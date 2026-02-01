import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../providers/pagoda_provider.dart';
import '../trips/create_trip_screen.dart';
import '../home/home_screen.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../../../core/localization/app_localizations.dart';

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
    final pagodaProvider = context.watch<PagodaProvider>();
    final livePagoda = pagodaProvider.allPagodas.firstWhere(
      (pagoda) => pagoda.id == widget.pagoda.id,
      orElse: () => widget.pagoda,
    );
    final isFavorite = livePagoda.isFavorite;
    final images = _buildImageList(widget.pagoda);
    final pagodaName = l10n.pagodaName(widget.pagoda.id, widget.pagoda.name);
    final pagodaDescription =
        l10n.pagodaDescription(widget.pagoda.id, widget.pagoda.description);
    final pagodaHistory = widget.pagoda.historicalInfo == null
        ? null
        : l10n.pagodaHistory(
            widget.pagoda.id,
            widget.pagoda.historicalInfo!,
          );
    final pagodaArchitecture = widget.pagoda.architecturalStyle == null
        ? null
        : l10n.pagodaArchitecture(
            widget.pagoda.id,
            widget.pagoda.architecturalStyle!,
          );
    final pagodaLegends = widget.pagoda.legends == null
        ? null
        : l10n.pagodaLegends(
            widget.pagoda.id,
            widget.pagoda.legends!,
          );
    final pagodaReligious = widget.pagoda.religiousImportance == null
        ? null
        : l10n.pagodaReligiousImportance(
            widget.pagoda.id,
            widget.pagoda.religiousImportance!,
          );
    final pagodaPreservation = widget.pagoda.preservationInfo == null
        ? null
        : l10n.pagodaPreservation(
            widget.pagoda.id,
            widget.pagoda.preservationInfo!,
          );
    final pagodaBestTime = widget.pagoda.bestTimeToVisit == null
        ? null
        : l10n.pagodaBestTime(
            widget.pagoda.id,
            widget.pagoda.bestTimeToVisit!,
          );
    final uniqueFeatures = widget.pagoda.uniqueFeatures;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pagodaName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 2),
                  ],
                ),
                maxLines: 1,
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
                          height: 320,
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
                        colors: [
                          Color(0x00000000),
                          Color(0x7A000000),
                        ],
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
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  context.read<PagodaProvider>().toggleFavorite(widget.pagoda.id);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(l10n.categoryLabel(widget.pagoda.category)),
                        backgroundColor: const Color(0xFFD4AF37),
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text(
                          '${widget.pagoda.latitude.toStringAsFixed(4)}, ${widget.pagoda.longitude.toStringAsFixed(4)}',
                        ),
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        avatar: Icon(
                          Icons.location_on,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: l10n.translate('pagoda.detail.category'),
                          value: l10n.categoryLabel(widget.pagoda.category),
                          icon: Icons.category,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: l10n.translate('pagoda.detail.year'),
                          value: widget.pagoda.yearBuilt?.toString() ??
                              l10n.translate('common.unknown'),
                          icon: Icons.event,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: l10n.translate('pagoda.detail.age'),
                          value: widget.pagoda.yearBuilt == null
                              ? l10n.translate('common.unknown')
                              : '${DateTime.now().year - widget.pagoda.yearBuilt!} ${l10n.translate('common.yearsShort')}',
                          icon: Icons.history,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: l10n.translate('pagoda.detail.overview'),
                    child: Text(
                      pagodaDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
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
                        if (widget.pagoda.height != null)
                          _InfoTile(
                            icon: Icons.height,
                            label: l10n.translate('pagoda.detail.height'),
                            value: widget.pagoda.height!,
                          ),
                        if (widget.pagoda.yearBuilt != null)
                          _InfoTile(
                            icon: Icons.event,
                            label: l10n.translate('pagoda.detail.yearBuilt'),
                            value: widget.pagoda.yearBuilt.toString(),
                          ),
                        _InfoTile(
                          icon: Icons.place,
                          label: l10n.translate('pagoda.detail.location'),
                          value:
                              '${widget.pagoda.latitude.toStringAsFixed(4)}, ${widget.pagoda.longitude.toStringAsFixed(4)}',
                        ),
                      ],
                    ),
                  ),
                  if (pagodaHistory != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.historicalInfo'),
                      child: Text(
                        pagodaHistory,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (pagodaLegends != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.legends'),
                      child: Text(
                        pagodaLegends,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (pagodaReligious != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.religiousImportance'),
                      child: Text(
                        pagodaReligious,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (pagodaPreservation != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.preservation'),
                      child: Text(
                        pagodaPreservation,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (uniqueFeatures.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.uniqueFeatures'),
                      child: Column(
                        children: uniqueFeatures
                            .map((feature) => _FeatureTile(feature: feature))
                            .toList(),
                      ),
                    ),
                  ],
                  if (widget.pagoda.visitorLocation != null || 
                      widget.pagoda.openingHours != null ||
                      widget.pagoda.dressCode != null ||
                      widget.pagoda.entranceFee != null ||
                      widget.pagoda.photographyRules != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.visitorInfo'),
                      child: Column(
                        children: [
                          if (widget.pagoda.visitorLocation != null)
                            _InfoTile(
                              icon: Icons.location_on,
                              label: l10n.translate('pagoda.detail.location'),
                              value: widget.pagoda.visitorLocation!,
                            ),
                          if (widget.pagoda.openingHours != null)
                            _InfoTile(
                              icon: Icons.access_time,
                              label: l10n.translate('pagoda.detail.openingHours'),
                              value: widget.pagoda.openingHours!,
                            ),
                          if (widget.pagoda.dressCode != null)
                            _InfoTile(
                              icon: Icons.checkroom,
                              label: l10n.translate('pagoda.detail.dressCode'),
                              value: widget.pagoda.dressCode!,
                            ),
                          if (widget.pagoda.entranceFee != null)
                            _InfoTile(
                              icon: Icons.confirmation_number,
                              label: l10n.translate('pagoda.detail.entranceFee'),
                              value: widget.pagoda.entranceFee!,
                            ),
                          if (widget.pagoda.photographyRules != null)
                            _InfoTile(
                              icon: Icons.photo_camera,
                              label: l10n.translate('pagoda.detail.photography'),
                              value: widget.pagoda.photographyRules!,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (pagodaBestTime != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.bestTimeToVisit'),
                      child: Text(
                        pagodaBestTime,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (widget.pagoda.finalWords != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: l10n.translate('pagoda.detail.finalWords'),
                      child: Text(
                        widget.pagoda.finalWords!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateTripScreen(
                              initialPagoda: widget.pagoda,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_road),
                      label: Text(l10n.translate('pagoda.detail.addToTrip')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(
                              initialIndex: 2,
                              initialMapPagoda: widget.pagoda,
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: Text(l10n.translate('pagoda.detail.viewOnMap')),
                      style: OutlinedButton.styleFrom(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feature.icon != null && feature.icon!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Text(
                feature.icon!,
                style: const TextStyle(fontSize: 20),
              ),
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
