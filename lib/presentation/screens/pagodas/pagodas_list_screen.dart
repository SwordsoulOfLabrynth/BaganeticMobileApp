import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../data/models/pagoda_model.dart';
import '../../providers/pagoda_provider.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';

class PagodasListScreen extends StatelessWidget {
  const PagodasListScreen({
    super.key,
    this.favoritesOnly = false,
    this.showBackButton = false,
  });

  final bool favoritesOnly;
  final bool showBackButton;

  static const _ivory = Color(0xFFF7F2E9);
  static const _ink = Color(0xFF100602);
  static const _brown = Color(0xFF2B1D14);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<PagodaProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFA34A2A),
                      ),
                    );
                  }

                  final pagodas = _orderedPagodas(
                    favoritesOnly ? provider.favorites : provider.pagodas,
                  );
                  if (pagodas.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              favoritesOnly
                                  ? Icons.bookmark_border_rounded
                                  : Icons.search_off_rounded,
                              size: 38,
                              color: const Color(0xFF8D7A6B),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              favoritesOnly
                                  ? context.l10n.translate('pagodas.noSaved')
                                  : context.l10n.translate('pagodas.empty'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF4E453F)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(30, 24, 30, 116),
                    itemCount: pagodas.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 48, color: Color(0x33C19A49)),
                    itemBuilder: (context, index) => JournalPagodaEntry(
                      pagoda: pagodas[index],
                      reversed: false,
                      imageAsset: _imageAssetFor(pagodas[index].id),
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PagodaDetailScreen(pagoda: pagodas[index]),
                        ),
                      ),
                      onToggleFavorite: () =>
                          _toggleFavorite(context, pagodas[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton)
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              icon: const Icon(Icons.arrow_back),
            ),
          if (showBackButton) const SizedBox(height: 12),
          Text(
            favoritesOnly
                ? context.l10n.translate('profile.savedPagodas')
                : context.l10n.translate('pagodas.title'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: _ink,
              fontSize: 34,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            favoritesOnly
                ? context.l10n.translate('pagodas.savedSubtitle')
                : context.l10n.translate('pagodas.subtitle'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _brown,
              fontSize: 12,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            onChanged: context.read<PagodaProvider>().setSearchQuery,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _ink),
            decoration: InputDecoration(
              hintText: context.l10n.translate('pagodas.searchHint'),
              hintStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFB7A9A1),
                letterSpacing: 1.9,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF80756F),
                size: 27,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.66),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Color(0xFF80756F)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Color(0xFFA34A2A), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Pagoda> _orderedPagodas(List<Pagoda> source) {
    final ordered = source.toList();
    const priority = {'ananda': 0, 'shwesandaw': 1, 'dhammayangyi': 2};
    ordered.sort(
      (a, b) => (priority[a.id] ?? 99).compareTo(priority[b.id] ?? 99),
    );
    return ordered;
  }

  Future<void> _toggleFavorite(BuildContext context, Pagoda pagoda) async {
    final provider = context.read<PagodaProvider>();
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('profile.favorites'),
    );
    if (canContinue && context.mounted) {
      await provider.toggleFavorite(pagoda.id);
    }
  }

  String? _imageAssetFor(String id) => switch (id) {
    'ananda' => 'assets/images/stitch/ananda_postcard.jpg',
    'shwesandaw' => 'assets/images/pagodas/researched/shwesandaw.jpg',
    _ => null,
  };
}

class JournalPagodaEntry extends StatelessWidget {
  const JournalPagodaEntry({
    super.key,
    required this.pagoda,
    required this.reversed,
    required this.imageAsset,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final Pagoda pagoda;
  final bool reversed;
  final String? imageAsset;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isRightAligned = reversed;
    final photo = imageAsset == null
        ? PagodaImageWidget(imageUrl: pagoda.imageUrl, fit: BoxFit.cover)
        : Image.asset(imageAsset!, fit: BoxFit.cover);
    final image = SizedBox(
      width: 128,
      height: 160,
      child: pagoda.isFavorite
          ? _BookmarkedPhoto(photo: photo)
          : Padding(padding: const EdgeInsets.all(8), child: photo),
    );
    final title = Text(
      context.l10n.pagodaName(
        pagoda.id,
        pagoda.name,
        remoteMyanmar: pagoda.nameMyanmar,
      ),
      textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF100602),
        fontSize: 22,
        height: 1.15,
      ),
    );
    final favoriteButton = SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onToggleFavorite,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: Icon(
          pagoda.isFavorite ? Icons.bookmark : Icons.bookmark_border,
          color: pagoda.isFavorite
              ? const Color(0xFFA34A2A)
              : const Color(0xFF80756F),
          size: 25,
        ),
      ),
    );
    final details = Expanded(
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: isRightAligned
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: isRightAligned
                  ? [
                      favoriteButton,
                      const SizedBox(width: 8),
                      Expanded(child: title),
                    ]
                  : [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      favoriteButton,
                    ],
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.translate(
                'pagodas.builtMeta',
                args: {
                  'year':
                      pagoda.yearBuilt?.toString() ??
                      context.l10n.translate('pagodas.historic'),
                },
              ),
              textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF4E453F),
                fontSize: 12,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.pagodaDescription(
                pagoda.id,
                pagoda.description,
                remoteMyanmar: pagoda.descriptionMyanmar,
              ),
              textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF4E453F),
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      // Titles vary between one and two lines. Starting both columns from the
      // same edge keeps the title, bookmark, and photo visually consistent.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isRightAligned
          ? [details, const SizedBox(width: 18), image]
          : [image, const SizedBox(width: 18), details],
    );
  }
}

class _BookmarkedPhoto extends StatelessWidget {
  const _BookmarkedPhoto({required this.photo});

  final Widget photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 19),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        border: Border.all(color: const Color(0xFFC19A49), width: 0.8),
      ),
      child: ClipRect(child: SizedBox.expand(child: photo)),
    );
  }
}
