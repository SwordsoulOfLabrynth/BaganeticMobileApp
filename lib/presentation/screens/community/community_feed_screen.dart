import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/community_post_model.dart';
import '../../providers/community_provider.dart';
import 'community_post_detail_screen.dart';
import 'create_community_post_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const double _actionStackClearance = 84;
  late final TextEditingController _searchController;

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
      appBar: AppBar(title: Text(l10n.translate('community.title'))),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, _) {
          final posts = provider.posts;
          return RefreshIndicator(
            onRefresh: provider.loadPosts,
            child: ResponsiveContent(
              child: ListView(
                padding: Responsive.pagePadding(context).copyWith(bottom: 148),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: provider.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: l10n.translate('community.searchHint'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.translate('community.filter.all')),
                        selected: provider.selectedType == 'all',
                        onSelected: (_) => provider.setSelectedType('all'),
                      ),
                      ChoiceChip(
                        label: Text(l10n.translate('community.type.tip')),
                        selected:
                            provider.selectedType == CommunityPost.typeTip,
                        onSelected: (_) =>
                            provider.setSelectedType(CommunityPost.typeTip),
                      ),
                      ChoiceChip(
                        label: Text(l10n.translate('community.type.question')),
                        selected:
                            provider.selectedType == CommunityPost.typeQuestion,
                        onSelected: (_) => provider.setSelectedType(
                          CommunityPost.typeQuestion,
                        ),
                      ),
                      DropdownButton<CommunityFeedSort>(
                        value: provider.sort,
                        borderRadius: BorderRadius.circular(12),
                        onChanged: (value) {
                          if (value != null) {
                            provider.setSort(value);
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: CommunityFeedSort.latest,
                            child: Text(
                              l10n.translate('community.sort.latest'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: CommunityFeedSort.helpful,
                            child: Text(
                              l10n.translate('community.sort.helpful'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: provider.availableTags
                        .map((tag) {
                          final label = tag == 'all'
                              ? l10n.translate('community.filter.allTags')
                              : l10n.translateOr('community.tag.$tag', tag);
                          return FilterChip(
                            label: Text(label),
                            selected: provider.selectedTag == tag,
                            onSelected: (_) => provider.setSelectedTag(tag),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
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
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _actionStackClearance),
        child: FloatingActionButton.small(
          heroTag: 'community-write-post',
          tooltip: l10n.translate('community.write'),
          onPressed: () => _openComposer(context),
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: Responsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isQuestion
                          ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                          : const Color(0xFFB8860B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.translate(
                        isQuestion
                            ? 'community.type.question'
                            : 'community.type.tip',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isQuestion
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF8B4513),
                      ),
                    ),
                  ),
                  Text(
                    '${post.authorName} • ${Helpers.formatDate(post.createdAt)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                post.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                post.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[800], height: 1.45),
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
              const SizedBox(height: 8),
              Row(
                children: [
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
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 18,
                            color: post.isUpvoted
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[700],
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
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Text('${post.commentCount}'),
                  const Spacer(),
                  TextButton(
                    onPressed: onOpen,
                    child: Text(l10n.translate('community.openDiscussion')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
