import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/community_post_model.dart';
import '../../providers/community_provider.dart';
import 'community_post_detail_screen.dart';
import 'create_community_post_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key, this.authorUserId, this.title});

  /// Restricts the feed to a single author's posts when supplied.
  final String? authorUserId;
  final String? title;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const double _actionStackClearance = 84;
  late final TextEditingController _searchController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<CommunityProvider>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openComposer(BuildContext context) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('community.write'),
    );
    if (!canContinue || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateCommunityPostScreen()),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 24,
        title: _CommunityHeading(
          title: widget.title ?? l10n.translate('community.title'),
          subtitle: l10n.translateOr(
            'community.subtitle',
            'Tips & questions from travelers',
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.translate('community.searchHint'),
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, _) {
          final isPersonalFeed = widget.authorUserId != null;
          final posts = isPersonalFeed
              ? provider.allPosts
                    .where((post) => post.authorUserId == widget.authorUserId)
                    .toList(growable: false)
              : provider.posts;
          return RefreshIndicator(
            onRefresh: provider.loadPosts,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 148),
              children: [
                if (!isPersonalFeed) ...[
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: _showSearch
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextField(
                              controller: _searchController,
                              onChanged: provider.setSearchQuery,
                              decoration: InputDecoration(
                                hintText: l10n.translate(
                                  'community.searchHint',
                                ),
                                prefixIcon: const Icon(Icons.search),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _TypeTabs(
                    selectedType: provider.selectedType,
                    onSelected: provider.setSelectedType,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: provider.availableTags
                          .where((tag) => tag != 'all')
                          .map((tag) {
                            final label = l10n.translateOr(
                              'community.tag.$tag',
                              tag,
                            );
                            final selected = provider.selectedTag == tag;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(label.toUpperCase()),
                                selected: selected,
                                onSelected: (_) => provider.setSelectedTag(
                                  selected ? 'all' : tag,
                                ),
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 4),
                if (provider.isLoading && provider.allPosts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (posts.isEmpty)
                  _EmptyFeed(onCreatePost: () => _openComposer(context))
                else
                  ...posts.map(
                    (post) => _CommunityPostCard(
                      post: post,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CommunityPostDetailScreen(postId: post.id),
                          ),
                        );
                      },
                      onToggleUpvote: () => _toggleUpvote(context, post),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _actionStackClearance),
        child: FloatingActionButton(
          heroTag: 'community-write-post',
          tooltip: l10n.translate('community.write'),
          onPressed: () => _openComposer(context),
          child: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _CommunityHeading extends StatelessWidget {
  const _CommunityHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF2B1D14),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w700,
            color: Color(0xFF81746B),
          ),
        ),
      ],
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selectedType, required this.onSelected});

  final String selectedType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = [
      ('all', l10n.translate('community.filter.all')),
      (CommunityPost.typeTip, l10n.translate('community.type.tip')),
      (CommunityPost.typeQuestion, l10n.translate('community.type.question')),
    ];
    return Wrap(
      spacing: 10,
      children: entries
          .map((entry) {
            final selected = selectedType == entry.$1;
            return ChoiceChip(
              label: Text(entry.$2.toUpperCase()),
              selected: selected,
              onSelected: (_) => onSelected(entry.$1),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              selectedColor: const Color(0xFF2B1D14),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF46372E),
                fontSize: 11,
                letterSpacing: 1.25,
                fontWeight: FontWeight.w700,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onCreatePost});

  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            l10n.translate('community.emptyTitle'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('community.emptyBody'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreatePost,
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.translate('community.write')),
          ),
        ],
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.onOpen,
    required this.onToggleUpvote,
  });

  final CommunityPost post;
  final VoidCallback onOpen;
  final VoidCallback onToggleUpvote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isQuestion = post.type == CommunityPost.typeQuestion;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      // inherit theme card shape (elevation: 0, radius: 3, hairline border)
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostTypeLabel(isQuestion: isQuestion),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF2B1D14),
                  fontWeight: FontWeight.w700,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                post.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF4E453F), height: 1.45),
              ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            l10n.translateOr('community.tag.$tag', tag),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFE5D9C7)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${post.authorName.toUpperCase()}  •  ${Helpers.formatDate(post.createdAt).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64584F),
                        fontSize: 10,
                        letterSpacing: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleUpvote,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            post.isUpvoted
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_up_outlined,
                            size: 18,
                            color: post.isUpvoted
                                ? const Color(0xFFA34A2A)
                                : const Color(0xFF786A5D),
                          ),
                          const SizedBox(width: 6),
                          Text('${post.upvoteCount}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: const Color(0xFF786A5D),
                  ),
                  const SizedBox(width: 6),
                  Text('${post.commentCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTypeLabel extends StatelessWidget {
  const _PostTypeLabel({required this.isQuestion});

  final bool isQuestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = isQuestion
        ? const Color(0xFFA34A2A)
        : const Color(0xFFB2842E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isQuestion ? Colors.transparent : color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .75)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        l10n
            .translate(
              isQuestion ? 'community.type.question' : 'community.type.tip',
            )
            .toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          letterSpacing: 1.05,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
