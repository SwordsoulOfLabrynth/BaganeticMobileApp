import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
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
  static const _parchment = Color(0xFFF7F2E9);
  static const _brown = Color(0xFF2B1D14);

  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommunityProvider>().loadComments(widget.postId);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleUpvote(CommunityPost post) async {
    final allowed = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('community.upvoteAction'),
    );
    if (allowed && mounted) {
      await context.read<CommunityProvider>().toggleUpvote(post.id);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) return;
    final l10n = context.l10n;
    final allowed = await AuthGate.ensureSignedIn(
      context,
      featureName: l10n.translate('community.commentAction'),
    );
    if (!allowed || !mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final now = DateTime.now();
    setState(() => _isSubmittingComment = true);
    try {
      await context.read<CommunityProvider>().addComment(
        CommunityComment(
          id: const Uuid().v4(),
          postId: widget.postId,
          authorUserId: user.uid,
          authorName: _userName(user.displayName, user.email),
          body: text,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      _commentController.clear();
      Helpers.showSnackBar(context, l10n.translate('community.commentSuccess'));
    } catch (error) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          l10n.translate('community.commentError', args: {'error': '$error'}),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (context, provider, _) {
        final post = provider.postById(widget.postId);
        if (post == null) {
          return const Scaffold(
            backgroundColor: _parchment,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final comments = provider.commentsForPost(widget.postId);
        return Scaffold(
          backgroundColor: _parchment,
          appBar: AppBar(
            backgroundColor: _parchment,
            title: Text(
              context.l10n.translate('community.post'),
              style: TextStyle(
                letterSpacing: 3,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                  children: [
                    _PostBoard(post: post, onVote: () => _toggleUpvote(post)),
                    const SizedBox(height: 32),
                    Text(
                      context.l10n.translate(
                        'community.answersCount',
                        args: {'count': '${post.commentCount}'},
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                        color: _brown,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (provider.isCommentsLoading(post.id))
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (comments.isEmpty)
                      const _EmptyAnswer()
                    else
                      ...comments.asMap().entries.map(
                        (entry) => _AnswerCard(
                          comment: entry.value,
                          featured: entry.key == 0,
                        ),
                      ),
                  ],
                ),
              ),
              _Composer(
                controller: _commentController,
                loading: _isSubmittingComment,
                onSend: _submitComment,
              ),
            ],
          ),
        );
      },
    );
  }

  String _userName(String? name, String? email) {
    final value = (name ?? '').trim();
    if (value.isNotEmpty) return value;
    return (email ?? 'User').split('@').first;
  }
}

class _PostBoard extends StatelessWidget {
  const _PostBoard({required this.post, required this.onVote});
  final CommunityPost post;
  final VoidCallback onVote;

  static const _brown = Color(0xFF2B1D14);
  static const _gold = Color(0xFFC19A49);

  @override
  Widget build(BuildContext context) {
    final question = post.isQuestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withValues(alpha: .6)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            context.l10n
                .translate(
                  question ? 'community.type.question' : 'community.type.tip',
                )
                .toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              color: Color(0xFF9B4425),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          post.title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: _brown,
            height: 1.18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _gold.withValues(alpha: .22),
              child: Text(
                post.authorName.isEmpty
                    ? '?'
                    : post.authorName[0].toUpperCase(),
                style: const TextStyle(
                  color: _brown,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              post.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 9),
            const Text('•', style: TextStyle(color: Color(0xFF978D84))),
            const SizedBox(width: 9),
            Text(
              Helpers.formatDate(post.createdAt).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF756C65),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          post.body,
          style: const TextStyle(fontSize: 18, height: 1.9, color: _brown),
        ),
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: post.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _gold.withValues(alpha: .6)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      tag.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: Color(0xFF756C65),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 26),
        const Divider(color: Color(0xFFE2D6BD)),
        Row(
          children: [
            TextButton.icon(
              onPressed: onVote,
              icon: Icon(
                post.isUpvoted
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_upward_outlined,
                color: _gold,
              ),
              label: Text(
                '${post.upvoteCount}',
                style: const TextStyle(color: Color(0xFF8D7650)),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chat_bubble_outline,
              size: 21,
              color: Color(0xFF756C65),
            ),
            const SizedBox(width: 8),
            Text(
              '${post.commentCount}',
              style: const TextStyle(color: Color(0xFF756C65)),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.comment, required this.featured});
  final CommunityComment comment;
  final bool featured;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 26),
    padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: const Color(0xFFE3D5B8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Stack(
      children: [
        if (featured)
          Positioned(
            left: -22,
            top: -20,
            bottom: -20,
            child: Container(width: 4, color: const Color(0xFFC19A49)),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured)
              Text(
                context.l10n.translate('community.topAnswer'),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: Color(0xFFC19A49),
                ),
              ),
            if (featured) const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(
                    0xFFC19A49,
                  ).withValues(alpha: .22),
                  child: Text(
                    comment.authorName.isEmpty
                        ? '?'
                        : comment.authorName[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    comment.authorName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  Helpers.formatDate(comment.createdAt).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: .7,
                    color: Color(0xFF8B827A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.body,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Color(0xFF40352D),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EmptyAnswer extends StatelessWidget {
  const _EmptyAnswer();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE3D5B8)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      context.l10n.translate('community.answersEmpty'),
      style: const TextStyle(height: 1.5, color: Color(0xFF756C65)),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: const Color(0xFFF7F2E9),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      child: Container(
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .76),
          border: Border.all(color: const Color(0xFFE2D0AA)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.translate('community.answerHint'),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: loading ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4425),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: loading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
