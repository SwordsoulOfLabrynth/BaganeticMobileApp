import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/travel_place.dart';

class TravelDiscoveryScreen extends StatefulWidget {
  const TravelDiscoveryScreen({
    super.key,
    required this.places,
    this.initialCategory,
  });

  final List<TravelPlace> places;
  final TravelPlaceCategory? initialCategory;

  @override
  State<TravelDiscoveryScreen> createState() => _TravelDiscoveryScreenState();
}

class _TravelDiscoveryScreenState extends State<TravelDiscoveryScreen> {
  late TravelPlaceCategory? _category = widget.initialCategory;
  String? _area;

  List<TravelPlace> get _places => widget.places.where((place) {
    return (_category == null || place.category == _category) &&
        (_area == null || place.area == _area);
  }).toList()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areas = widget.places.map((place) => place.area).toSet().toList()
      ..sort();
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF3),
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.translate('discover.title')),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.translate('discover.featured'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFA34A2A),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.translate('discover.subtitle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF66584D),
                    ),
                  ),
                ],
              ),
            ),
            _FilterRow<TravelPlaceCategory?>(
              values: [null, ...TravelPlaceCategory.values],
              selected: _category,
              label: (category) => category == null
                  ? context.l10n.translate('discover.all')
                  : _categoryLabel(context, category),
              onSelected: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: 8),
            _FilterRow<String?>(
              values: [null, ...areas],
              selected: _area,
              label: (area) => area ?? context.l10n.translate('discover.all'),
              onSelected: (area) => setState(() => _area = area),
              subdued: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                context.l10n.translate(
                  'discover.showingCount',
                  args: {'count': _places.length.toString()},
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF786A5D),
                ),
              ),
            ),
            Expanded(
              child: _places.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.l10n.translate('discover.noPlaces'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: _places.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _PlaceCard(
                        place: _places[index],
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TravelPlaceDetailScreen(place: _places[index]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TravelPlaceDetailScreen extends StatelessWidget {
  const TravelPlaceDetailScreen({super.key, required this.place});
  final TravelPlace place;

  @override
  Widget build(BuildContext context) {
    final isMyanmar = Localizations.localeOf(context).languageCode == 'my';
    final theme = Theme.of(context);
    final color = _categoryColor(place.category);
    final highlights = isMyanmar ? place.highlightsMyanmar : place.highlights;
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
            const SizedBox(height: 6),
            Text(
              _travelImageAttribution(place),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF786A5D),
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
                  Icon(Icons.account_balance_wallet_outlined, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.translate('discover.estimatedPrice'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          place.localPriceEstimate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF30251D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.l10n.translate('discover.usdReference')}: ${isMyanmar ? place.priceEstimateMyanmar : place.priceEstimate}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF66584D),
                          ),
                        ),
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

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onOpen});
  final TravelPlace place;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isMyanmar = Localizations.localeOf(context).languageCode == 'my';
    final color = _categoryColor(place.category);
    return Semantics(
      button: true,
      label: '${isMyanmar ? place.nameMyanmar : place.name}, ${place.area}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 132,
            child: Row(
              children: [
                _AreaImage(place: place, width: 112),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMyanmar ? place.nameMyanmar : place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF30251D),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        _AreaPill(area: place.area),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                place.localPriceEstimate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: color),
                          ],
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
  const _AreaImage({required this.place, this.width, this.height, this.child});
  final TravelPlace place;
  final double? width;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            place.imageAsset ?? _categoryImageAsset(place.category),
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

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.subdued = false,
  });
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final bool subdued;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = value == this.selected;
        final color = subdued
            ? const Color(0xFF66584D)
            : const Color(0xFFA34A2A);
        return ChoiceChip(
          label: Text(label(value)),
          selected: selected,
          onSelected: (_) => onSelected(value),
          selectedColor: color,
          labelStyle: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: color.withValues(alpha: 0.28)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
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

String _categoryImageAsset(TravelPlaceCategory category) => switch (category) {
  TravelPlaceCategory.stay => 'assets/images/travel/bagan-hotel-context.jpg',
  TravelPlaceCategory.food => 'assets/images/travel/sanon-restaurant.jpg',
  TravelPlaceCategory.transport => 'assets/images/travel/bagan-e-bike.jpg',
};

String _travelImageAttribution(TravelPlace place) =>
    place.imageAttribution ??
    switch (place.category) {
      TravelPlaceCategory.stay =>
        'Representative Bagan stay photo: Chris and Denis Luyten-De Hauwere, CC BY 4.0 (view from Thande Hotel).',
      TravelPlaceCategory.food =>
        'Representative Bagan restaurant photo: Etan J. Tal, CC BY-SA 4.0 (Sanon training restaurant).',
      TravelPlaceCategory.transport =>
        'Representative Bagan transport photo: Jakub Hałun, CC BY-SA 4.0 (e-bike on the Bagan plain).',
    };

IconData _categoryIcon(TravelPlaceCategory category) => switch (category) {
  TravelPlaceCategory.stay => Icons.hotel_rounded,
  TravelPlaceCategory.food => Icons.restaurant_rounded,
  TravelPlaceCategory.transport => Icons.directions_transit_rounded,
};

String _categoryLabel(BuildContext context, TravelPlaceCategory category) =>
    context.l10n.translate(switch (category) {
      TravelPlaceCategory.stay => 'map.category.stays',
      TravelPlaceCategory.food => 'map.category.food',
      TravelPlaceCategory.transport => 'map.category.transport',
    });

Color _categoryColor(TravelPlaceCategory category) => switch (category) {
  TravelPlaceCategory.stay => const Color(0xFF91624E),
  TravelPlaceCategory.food => const Color(0xFFA34A2A),
  TravelPlaceCategory.transport => const Color(0xFF166B91),
};
