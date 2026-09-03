import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/community_post_model.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/pagoda_image_widget.dart';
import '../community/community_post_detail_screen.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../trips/create_trip_screen.dart';
import '../trips/trip_detail_screen.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({super.key, required this.onNavigateToTab});

  final void Function(int) onNavigateToTab;

  static const _heroAsset = 'assets/images/stitch/bagan_sunrise.jpg';
  // These editorial covers preserve the Home screen's travel-journal mood.
  // Other admin-selected featured pagodas fall back to their catalog image.
  static const _curatedHomeCovers = {
    'ananda': 'assets/images/stitch/ananda_postcard.jpg',
    'shwesandaw': 'assets/images/stitch/shwesandaw_postcard.jpg',
  };
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 94 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(context),
            const SizedBox(height: 20),
            _buildPopularPagodas(context),
            const SizedBox(height: 42),
            _buildCommunity(context),
            const SizedBox(height: 42),
            _buildTrips(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final user = context.watch<AuthProvider>().user;
    final localPhotoPath = context.watch<AuthProvider>().localProfilePhotoPath;
    final photoUrl = user?.photoURL?.trim() ?? '';
    final displayName = (user?.displayName ?? user?.email ?? 'B').trim();
    return SizedBox(
      // Leave enough room for the Popular Pagodas section on first entry.
      height: Responsive.isTabletOrLarger(context) ? 400 : 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_heroAsset, fit: BoxFit.cover),
          // Flat matte scrim — spec prohibits gradients
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x40000000)),
          ),
          const _HeroDustOverlay(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Baganetic',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white, fontSize: 24),
                    ),
                    InkWell(
                      onTap: () => onNavigateToTab(4),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x99FFFFFF),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: localPhotoPath != null
                              ? Image.file(
                                  File(localPhotoPath),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _HomeAvatarInitial(name: displayName),
                                )
                              : photoUrl.isNotEmpty
                              ? Image.network(
                                  photoUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _HomeAvatarInitial(name: displayName),
                                )
                              : _HomeAvatarInitial(name: displayName),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  context.l10n.translate('home.journalGreeting'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  context.l10n.translate('home.journalHeadline'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.18,
                    shadows: const [
                      Shadow(color: Color(0x55000000), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom transition: removed gradient per spec (matte/no-gradient rule)
        ],
      ),
    );
  }

  Widget _buildPopularPagodas(BuildContext context) {
    return Consumer<PagodaProvider>(
      builder: (context, provider, _) {
        final pagodas = provider.homeFeaturedPagodas;
        if (pagodas.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _sectionHeader(
                context,
                context.l10n.translate('home.journalPopular'),
                onViewAll: () => onNavigateToTab(1),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 350,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: pagodas.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final pagoda = pagodas[index];
                  return _PopularPagodaTile(
                    pagoda: pagoda,
                    coverImageUrl:
                        _curatedHomeCovers[pagoda.id] ?? pagoda.imageUrl,
                    onTap: () => _openPagoda(context, pagoda),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunity(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (context, provider, _) {
        final posts = provider.posts.take(2).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                context.l10n.translate('home.journalCommunity'),
                onViewAll: () => onNavigateToTab(3),
              ),
              const SizedBox(height: 18),
              if (provider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (posts.isEmpty)
                _EmptyJournalCard(onTap: () => onNavigateToTab(3))
              else
                ...posts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CommunityPreview(
                      post: post,
                      imageAsset: posts.indexOf(post).isEven
                          ? 'assets/images/stitch/shwesandaw_postcard.jpg'
                          : 'assets/images/stitch/ananda_postcard.jpg',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommunityPostDetailScreen(postId: post.id),
                        ),
                      ),
                      onToggleUpvote: () => _toggleUpvote(context, post),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleUpvote(BuildContext context, CommunityPost post) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('community.upvoteAction'),
    );
    if (!canContinue || !context.mounted) {
      return;
    }

    await context.read<CommunityProvider>().toggleUpvote(post.id);
  }

  Widget _buildTrips(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trips = provider.trips.take(2).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                context.l10n.translate('home.journalTrips'),
                onViewAll: () => onNavigateToTab(2),
              ),
              const SizedBox(height: 18),
              if (trips.isEmpty)
                _EmptyTripCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  ),
                )
              else
                ...trips.map(
                  (trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripPreview(
                      trip: trip,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripDetailScreen(trip: trip),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    required VoidCallback onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(letterSpacing: 1.5),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFC19A49),
            padding: EdgeInsets.zero,
          ),
          child: Text(context.l10n.translate('common.viewAll')),
        ),
      ],
    );
  }

  void _openPagoda(BuildContext context, Pagoda pagoda) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PagodaDetailScreen(pagoda: pagoda)),
  );
}

class _PopularPagodaTile extends StatelessWidget {
  const _PopularPagodaTile({
    required this.pagoda,
    required this.coverImageUrl,
    required this.onTap,
  });
  final Pagoda pagoda;
  final String coverImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.pagodaName(
      pagoda.id,
      pagoda.name,
      remoteMyanmar: pagoda.nameMyanmar,
    );
    final year = pagoda.yearBuilt?.toString() ?? '';
    return SizedBox(
      width: 232,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 286,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF9F2),
                border: Border.all(color: const Color(0xFFD2C4BD)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x15000000),
                    blurRadius: 8,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: PagodaImageWidget(
                imageUrl: coverImageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 2),
            if (year.isNotEmpty)
              Text(
                context.l10n.translate(
                  'home.featuredYear',
                  args: {'year': year},
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 0.9),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview({
    required this.post,
    required this.imageAsset,
    required this.onTap,
    required this.onToggleUpvote,
  });
  final CommunityPost post;
  // imageAsset kept in signature for API compatibility but not rendered
  // (community posts are text-only tips/questions — no photos)
  final String imageAsset;
  final VoidCallback onTap;
  final VoidCallback onToggleUpvote;

  static const _tipColor = Color(0xFFC19A49); // antique gold
  static const _questionBorder = Color(0xFFA34A2A); // terracotta

  @override
  Widget build(BuildContext context) {
    final isQuestion = post.type == CommunityPost.typeQuestion;
    final body = post.body.isNotEmpty ? post.body : post.title;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x99FFFFFF),
          border: Border.all(color: const Color(0xFFD2C4BD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge row (TIP or QUESTION) — no photos
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isQuestion
                        ? Colors.transparent
                        : _tipColor.withValues(alpha: 0.14),
                    border: isQuestion
                        ? Border.all(color: _questionBorder, width: 0.8)
                        : null,
                  ),
                  child: Text(
                    isQuestion ? 'QUESTION' : 'TIP',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: isQuestion
                          ? _questionBorder
                          : const Color(0xFF7A5C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.authorName.isEmpty
                        ? 'Bagan traveler'
                        : post.authorName,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: const Color(0xFF4E453F),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onToggleUpvote,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          post.isUpvoted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: post.isUpvoted
                              ? const Color(0xFFA34A2A)
                              : const Color(0xFF786A5D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post.upvoteCount}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF4E453F),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 17,
                  color: Color(0xFF4E453F),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyJournalCard extends StatelessWidget {
  const _EmptyJournalCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        border: Border.all(color: const Color(0xFFD2C4BD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_outlined, color: Color(0xFF9B4425)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.translate('home.journalEmptyCommunity'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFF9B4425),
          ),
        ],
      ),
    ),
  );
}

class _TripPreview extends StatelessWidget {
  const _TripPreview({required this.trip, required this.onTap});
  final Trip trip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB3E7E2D9),
        border: Border.all(color: const Color(0x4D80756F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.translate(
                    'home.tripSummary',
                    args: {
                      'count': '${trip.stops.length}',
                      'distance': trip.getTotalDistance().toStringAsFixed(1),
                      'mode': Helpers.transportModeLabel(
                        context,
                        trip.transportMode,
                      ).toUpperCase(),
                    },
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(letterSpacing: 0.7),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B4425)),
        ],
      ),
    ),
  );
}

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB3E7E2D9),
        border: Border.all(color: const Color(0x4D80756F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.translate('home.journalPlanFirst'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.translate('home.journalPlanFirstSubtitle'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(letterSpacing: 0.7),
                ),
              ],
            ),
          ),
          const Icon(Icons.add_rounded, color: Color(0xFF9B4425)),
        ],
      ),
    ),
  );
}

class _HomeAvatarInitial extends StatelessWidget {
  const _HomeAvatarInitial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF0D9A9),
    alignment: Alignment.center,
    child: Text(
      name.isEmpty ? 'B' : name[0].toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF2B1D14),
        fontFamily: 'PlayfairDisplay',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A restrained dawn-dust layer that keeps the photograph and copy readable.
/// It is intentionally non-interactive and honours the device motion setting.
class _HeroDustOverlay extends StatefulWidget {
  const _HeroDustOverlay();

  @override
  State<_HeroDustOverlay> createState() => _HeroDustOverlayState();
}

class _HeroDustOverlayState extends State<_HeroDustOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reduceMotion) return;
    _reducedMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _HeroDustPainter(
                progress: _reducedMotion == true ? 0.24 : _controller.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDustPainter extends CustomPainter {
  const _HeroDustPainter({required this.progress});

  final double progress;

  // Long smoke ribbons are deliberately visible from a normal viewing
  // distance, inspired by a game lobby's living atmospheric backdrop.
  static const _wisps = <_DustWisp>[
    _DustWisp(0.18, 0.68, 0.052, 0.34, 0.08),
    _DustWisp(0.34, 0.76, 0.064, 0.28, 0.37),
    _DustWisp(0.51, 0.64, 0.058, 0.32, 0.71),
    _DustWisp(0.66, 0.70, 0.048, 0.24, 0.93),
  ];

  // Original small, soft motes: an accent for the smoke, not a glitter layer.
  static const _motes = <_DustMote>[
    _DustMote(0.03, 0.17, 1.6, 0.22, 0.11, 0.58),
    _DustMote(0.14, 0.30, 2.3, 0.16, 0.78, 0.88),
    _DustMote(0.24, 0.13, 1.2, 0.24, 0.36, 0.64),
    _DustMote(0.32, 0.44, 2.8, 0.18, 0.59, 0.78),
    _DustMote(0.40, 0.24, 1.5, 0.20, 0.17, 0.72),
    _DustMote(0.48, 0.56, 2.0, 0.16, 0.91, 0.56),
    _DustMote(0.55, 0.11, 2.5, 0.13, 0.46, 0.94),
    _DustMote(0.62, 0.36, 1.4, 0.25, 0.68, 0.66),
    _DustMote(0.69, 0.49, 3.0, 0.14, 0.29, 0.82),
    _DustMote(0.76, 0.20, 1.9, 0.22, 0.84, 0.61),
    _DustMote(0.82, 0.65, 2.4, 0.15, 0.52, 0.75),
    _DustMote(0.90, 0.33, 1.3, 0.23, 0.05, 0.92),
    _DustMote(0.96, 0.54, 2.7, 0.12, 0.72, 0.69),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final wisp in _wisps) {
      final wave = (progress * math.pi * 2) + wisp.phase * math.pi * 2;
      final drift = math.sin(wave) * size.width * 0.10;
      final y =
          wisp.y * size.height + math.cos(wave * 1.5) * size.height * 0.018;
      final start = Offset(-size.width * 0.20 + drift, y);
      final end = Offset(start.dx + wisp.length * size.width, y);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + size.width * 0.20,
          start.dy - size.height * 0.08,
          end.dx - size.width * 0.24,
          end.dy + size.height * 0.07,
          end.dx,
          end.dy - size.height * 0.012,
        );
      final intensity = 0.80 + math.sin(wave * 0.75).abs() * 0.20;
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE2A15C).withValues(
            alpha: wisp.opacity * intensity * 0.66,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * wisp.thickness * 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            size.height * wisp.thickness * 1.25,
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD39A).withValues(
            alpha: wisp.opacity * intensity,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * wisp.thickness
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            size.height * wisp.thickness * 0.35,
          ),
      );
    }

    for (final mote in _motes) {
      final travel = (progress * mote.speed + mote.phase) % 1.0;
      final x = (mote.x + travel * 0.24) % 1.12 - 0.06;
      final y = mote.y +
          math.sin((progress * math.pi * 2) + mote.phase * math.pi) * 0.012;
      if (x < 0 || x > 1 || y < 0 || y > 1) continue;

      final shimmer = 0.72 +
          0.28 * math.sin((progress * math.pi * 2) + mote.phase * 7);
      final radius = mote.radius * (size.shortestSide / 360);
      final center = Offset(x * size.width, y * size.height);
      final color = const Color(0xFFFFE0A2).withValues(
        alpha: mote.opacity * shimmer,
      );

      canvas.drawCircle(
        center,
        radius * 2.3,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.5),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroDustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DustWisp {
  const _DustWisp(
    this.y,
    this.length,
    this.thickness,
    this.opacity,
    this.phase,
  );

  final double y;
  final double length;
  final double thickness;
  final double opacity;
  final double phase;
}

class _DustMote {
  const _DustMote(
    this.x,
    this.y,
    this.radius,
    this.opacity,
    this.phase,
    this.speed,
  );

  final double x;
  final double y;
  final double radius;
  final double opacity;
  final double phase;
  final double speed;
}
