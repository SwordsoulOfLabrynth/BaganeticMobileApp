import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/community_post_model.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../community/community_post_detail_screen.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../trips/create_trip_screen.dart';
import '../trips/trip_detail_screen.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({super.key, required this.onNavigateToTab});

  final void Function(int) onNavigateToTab;

  static const _heroAsset = 'assets/images/stitch/bagan_sunrise.jpg';
  static const _popularCards = [
    _PopularCard(
      'ananda',
      'Ananda Temple',
      'assets/images/stitch/ananda_postcard.jpg',
      '1105 AD',
    ),
    _PopularCard(
      'shwesandaw',
      'Shwesandaw Pagoda',
      'assets/images/stitch/shwesandaw_postcard.jpg',
      '1057 AD',
    ),
  ];

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
        final pagodas = <Pagoda>[];
        for (final card in _popularCards) {
          final match = provider.allPagodas.where(
            (item) => item.id == card.pagodaId,
          );
          if (match.isNotEmpty) pagodas.add(match.first);
        }
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
                itemCount: _popularCards.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final card = _popularCards[index];
                  final matches = pagodas.where(
                    (item) => item.id == card.pagodaId,
                  );
                  final pagoda = matches.isEmpty ? null : matches.first;
                  return _PopularPagodaTile(
                    card: card,
                    pagoda: pagoda,
                    onTap: pagoda == null
                        ? () => onNavigateToTab(1)
                        : () => _openPagoda(context, pagoda),
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
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
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

class _PopularCard {
  const _PopularCard(this.pagodaId, this.title, this.asset, this.year);
  final String pagodaId;
  final String title;
  final String asset;
  final String year;
}

class _PopularPagodaTile extends StatelessWidget {
  const _PopularPagodaTile({
    required this.card,
    required this.pagoda,
    required this.onTap,
  });
  final _PopularCard card;
  final Pagoda? pagoda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.pagodaName(
      card.pagodaId,
      pagoda?.name ?? card.title,
      remoteMyanmar: pagoda?.nameMyanmar,
    );
    final year = card.year.replaceAll(' AD', '');
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
              child: Image.asset(
                card.asset,
                width: double.infinity,
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
            Text(
              context.l10n.translate('home.featuredYear', args: {'year': year}),
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
  });
  final CommunityPost post;
  // imageAsset kept in signature for API compatibility but not rendered
  // (community posts are text-only tips/questions — no photos)
  final String imageAsset;
  final VoidCallback onTap;

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
                const Icon(
                  Icons.favorite_border_rounded,
                  size: 18,
                  color: Color(0xFFA34A2A),
                ),
                const SizedBox(width: 5),
                Text(
                  '${post.upvoteCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF4E453F),
                    fontWeight: FontWeight.w700,
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
