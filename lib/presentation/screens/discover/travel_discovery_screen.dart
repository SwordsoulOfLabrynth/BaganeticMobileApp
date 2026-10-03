import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/travel_place.dart';

class TravelPlaceDetailScreen extends StatelessWidget {
  const TravelPlaceDetailScreen({super.key, required this.place});
  final TravelPlace place;

  @override
  Widget build(BuildContext context) {
    final isMyanmar = Localizations.localeOf(context).languageCode == 'my';
    final theme = Theme.of(context);
    final color = _categoryColor(place.category);
    final highlights = isMyanmar ? place.highlightsMyanmar : place.highlights;
    final isScenery = place.category == TravelPlaceCategory.scenery;
    final bestTime = isMyanmar ? place.bestTimeMyanmar : place.bestTime;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF3),
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.translate('discover.details')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _AreaImage(
              place: place,
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _categoryLabel(context, place.category).toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMyanmar ? place.nameMyanmar : place.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AreaPill(area: place.area, dark: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    isScenery
                        ? Icons.wb_sunny_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.translate(
                            isScenery
                                ? 'discover.bestPhotoTime'
                                : 'discover.estimatedPrice',
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isScenery ? (bestTime ?? place.priceEstimate) : place.localPriceEstimate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF30251D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!isScenery) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.l10n.translate('discover.usdReference')}: ${isMyanmar ? place.priceEstimateMyanmar : place.priceEstimate}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF66584D),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isMyanmar ? place.summaryMyanmar : place.summary,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF3C3129),
                height: 1.45,
              ),
            ),
            if (isScenery) ...[
              const SizedBox(height: 20),
              if (place.seasonNote != null || place.photoTip != null)
                _SceneryGuidance(
                  seasonNote: isMyanmar
                      ? place.seasonNoteMyanmar ?? place.seasonNote
                      : place.seasonNote,
                  photoTip: isMyanmar
                      ? place.photoTipMyanmar ?? place.photoTip
                      : place.photoTip,
                ),
            ],
            const SizedBox(height: 20),
            Text(
              context.l10n.translate('discover.highlights'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xFF30251D),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: highlights
                  .map(
                    (highlight) =>
                        _HighlightChip(label: highlight, color: color),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
            Text(
              isMyanmar ? place.noteMyanmar : place.note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF66584D),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.translate('discover.estimateNotice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF786A5D),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TravelPlaceCard extends StatelessWidget {
  const TravelPlaceCard({super.key, required this.place, required this.onOpen});
  final TravelPlace place;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isMyanmar = Localizations.localeOf(context).languageCode == 'my';
    final color = _categoryColor(place.category);
    final isScenery = place.category == TravelPlaceCategory.scenery;
    final bestTime = isMyanmar ? place.bestTimeMyanmar ?? place.bestTime : place.bestTime;
    final primaryDetail = isScenery
        ? bestTime ?? place.priceEstimate
        : place.localPriceEstimate;
    final name = isMyanmar ? place.nameMyanmar : place.name;
    final summary = isMyanmar ? place.summaryMyanmar : place.summary;
    return Semantics(
      button: true,
      label: '$name, ${_categoryLabel(context, place.category)}, ${place.area}, $primaryDetail',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AreaImage(
                  place: place,
                  width: 120,
                  height: 148,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF100602),
                                fontSize: 20,
                                height: 1.18,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              isScenery
                                  ? Icons.wb_sunny_outlined
                                  : Icons.sell_outlined,
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                primaryDetail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: color,
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4E453F),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaImage extends StatelessWidget {
  const _AreaImage({
    required this.place,
    this.width,
    this.height,
    this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });
  final TravelPlace place;
  final double? width;
  final double? height;
  final Widget? child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _placeImageAsset(place),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: _categoryColor(place.category).withValues(alpha: 0.18),
              child: Center(
                child: Icon(
                  _categoryIcon(place.category),
                  color: _categoryColor(place.category),
                  size: 38,
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x10000000), Color(0xAA21110A)],
              ),
            ),
          ),
          if (child case final Widget child) child,
          if (child == null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                place.area,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SceneryGuidance extends StatelessWidget {
  const _SceneryGuidance({this.seasonNote, this.photoTip});

  final String? seasonNote;
  final String? photoTip;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF3E8D7),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (seasonNote != null) ...[
          Text(context.l10n.translate('discover.seasonalLight'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF7A4B2C), fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(seasonNote!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35)),
        ],
        if (seasonNote != null && photoTip != null) const SizedBox(height: 14),
        if (photoTip != null) ...[
          Text(context.l10n.translate('discover.photoTip'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF7A4B2C), fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(photoTip!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35)),
        ],
      ],
    ),
  );
}

class _AreaPill extends StatelessWidget {
  const _AreaPill({required this.area, this.dark = false});
  final String area;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: dark ? const Color(0x30FFFFFF) : const Color(0xFFF3E8D7),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      area,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: dark ? Colors.white : const Color(0xFF66584D),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

IconData _categoryIcon(TravelPlaceCategory category) => switch (category) {
  TravelPlaceCategory.stay => Icons.hotel_rounded,
  TravelPlaceCategory.food => Icons.restaurant_rounded,
  TravelPlaceCategory.transport => Icons.directions_transit_rounded,
  TravelPlaceCategory.scenery => Icons.photo_camera_outlined,
};

String _categoryLabel(BuildContext context, TravelPlaceCategory category) =>
    context.l10n.translate(switch (category) {
      TravelPlaceCategory.stay => 'map.category.stays',
      TravelPlaceCategory.food => 'map.category.food',
      TravelPlaceCategory.transport => 'map.category.transport',
      TravelPlaceCategory.scenery => 'map.category.scenery',
    });

Color _categoryColor(TravelPlaceCategory category) => switch (category) {
  TravelPlaceCategory.stay => const Color(0xFF91624E),
  TravelPlaceCategory.food => const Color(0xFFA34A2A),
  TravelPlaceCategory.transport => const Color(0xFF166B91),
  TravelPlaceCategory.scenery => const Color(0xFF7A4B2C),
};

String _placeImageAsset(TravelPlace place) => switch (place.id) {
  'sulamani-ground-view' => 'assets/images/pagodas/Sulamani Temple/sulamani-temple-bagan-myanmar-sunset-asia-82328684.webp',
  'bupaya-riverside-view' => 'assets/images/pagodas/BuPaya/Bupaya-Pagoda-and-Irrawaddy-in-the-back.jpg',
  'law-ka-ou-saung-field' => 'assets/images/pagodas/researched/lawkaousaung.jpg',
  'north-guni-field-view' => 'assets/images/pagodas/researched/northguni.jpg',
  'dhammayazika-ground-view' => 'assets/images/pagodas/Dhammayazaka/dhammayazika-pagoda-l.jpg',
  _ => 'assets/images/stitch/bagan_sunrise.jpg',
};
