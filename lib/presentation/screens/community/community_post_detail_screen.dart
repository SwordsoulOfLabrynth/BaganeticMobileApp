import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/community_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<CommunityProvider>().loadComments(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleUpvote(CommunityPost post) async {
    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('community.upvoteAction'),
    );
    if (!canContinue || !mounted) {
      return;
    }
    await context.read<CommunityProvider>().toggleUpvote(post.id);
  }

  Future<void> _submitComment() async {
    final l10n = context.l10n;
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) {
      return;
    }

    final canContinue = await AuthGate.ensureSignedIn(
      context,
      featureName: l10n.translate('community.commentAction'),
    );
    if (!canContinue || !mounted) {
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    final now = DateTime.now();
    final comment = CommunityComment(
      id: const Uuid().v4(),
      postId: widget.postId,
      authorUserId: user.uid,
      authorName: _displayNameForUser(user.displayName, user.email),
      body: text,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      await context.read<CommunityProvider>().addComment(comment);
      if (!mounted) {
        return;
      }
      _commentController.clear();
      Helpers.showSnackBar(context, l10n.translate('community.commentSuccess'));
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        l10n.translate('community.commentError', args: {'error': e.toString()}),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (context, provider, _) {
        final post = provider.postById(widget.postId);
        final comments = provider.commentsForPost(widget.postId);
        final isLoadingComments = provider.isCommentsLoading(widget.postId);
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(
            title: Text(post?.title ?? l10n.translate('community.title')),
          ),
          body: post == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: Responsive.pagePadding(context),
                        children: [
                          _PostDetailCard(
                            post: post,
                            onToggleUpvote: () => _toggleUpvote(post),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                l10n.translate('community.commentsTitle'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${post.commentCount}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isLoadingComments)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (comments.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                l10n.translate('community.commentsEmpty'),
                              ),
                            )
                          else
                            ...comments.map(
                              (comment) => _CommentCard(comment: comment),
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: l10n.translate(
                                    'community.commentHint',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isSubmittingComment
                                  ? null
                                  : _submitComment,
                              icon: _isSubmittingComment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _displayNameForUser(String? displayName, String? email) {
    final trimmedName = (displayName ?? '').trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    final emailPrefix = (email ?? '').split('@').first.trim();
    if (emailPrefix.isNotEmpty) {
      return emailPrefix;
    }
    return 'User';
  }
}

class _PostDetailCard extends StatelessWidget {
  const _PostDetailCard({required this.post, required this.onToggleUpvote});

  final CommunityPost post;
  final VoidCallback onToggleUpvote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                _TypeBadge(type: post.type),
                Text(
                  '${post.authorName} • ${Helpers.formatDate(post.createdAt)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(post.body, style: const TextStyle(height: 1.5, fontSize: 16)),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onToggleUpvote,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.isUpvoted
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: post.isUpvoted
                              ? theme.colorScheme.primary
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.translate(
                            'community.upvotesCount',
                            args: {'count': '${post.upvoteCount}'},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.translate(
                    'community.commentsCount',
                    args: {'count': '${post.commentCount}'},
                  ),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.authorName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            Helpers.formatDate(comment.createdAt),
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(comment.body),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final isQuestion = type == CommunityPost.typeQuestion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isQuestion
            ? const Color(0xFF0F766E).withValues(alpha: 0.12)
            : const Color(0xFFB8860B).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.translate(
          isQuestion ? 'community.type.question' : 'community.type.tip',
        ),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isQuestion ? const Color(0xFF0F766E) : const Color(0xFF8B4513),
        ),
      ),
    );
  }
}
