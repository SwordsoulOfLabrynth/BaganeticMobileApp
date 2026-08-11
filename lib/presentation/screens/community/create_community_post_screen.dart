import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/community_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/sign_in_required_view.dart';

class CreateCommunityPostScreen extends StatefulWidget {
  const CreateCommunityPostScreen({super.key});
  @override
  State<CreateCommunityPostScreen> createState() =>
      _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState extends State<CreateCommunityPostScreen> {
  static const _parchment = Color(0xFFF7F2E9);
  static const _brown = Color(0xFF2B1D14);
  static const _terracotta = Color(0xFF9B4425);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<String> _selectedTags = {};
  String _type = CommunityPost.typeTip;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    if (context.read<AuthProvider>().user == null) {
      final allowed = await AuthGate.ensureSignedIn(
        context,
        featureName: context.l10n.translate('community.write'),
      );
      if (!allowed || !mounted) {
        return;
      }
    }
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }
    final now = DateTime.now();
    setState(() => _isSubmitting = true);
    try {
      await context.read<CommunityProvider>().createPost(
        CommunityPost(
          id: const Uuid().v4(),
          authorUserId: user.uid,
          authorName: _name(user.displayName, user.email),
          type: _type,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          tags: _selectedTags.toList()..sort(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        context.l10n.translate('community.submitSuccess'),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          context.l10n.translate(
            'community.submitError',
            args: {'error': '$error'},
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (context.select<AuthProvider, bool>((auth) => auth.user != null) ==
        false) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.translate('community.write'))),
        body: SignInRequiredView(
          icon: Icons.forum_outlined,
          message: l10n.translate('community.signInPrompt'),
          onSignIn: () => AuthGate.openSignIn(context),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _parchment,
      appBar: AppBar(
        backgroundColor: _parchment,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.translate('community.newPost')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _terracotta,
                shape: const StadiumBorder(),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.translate('community.post')),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(36, 40, 36, 48),
          children: [
            _Kicker(l10n.translate('community.typeLabel')),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 340;
                return Row(
                  children: [
                    _TypeCard(
                      compact: isCompact,
                      selected: _type == CommunityPost.typeTip,
                      icon: Icons.lightbulb_outline_rounded,
                      title: l10n.translate('community.type.tip'),
                      subtitle: l10n.translate('community.tipSubtitle'),
                      onTap: () =>
                          setState(() => _type = CommunityPost.typeTip),
                    ),
                    SizedBox(width: isCompact ? 18 : 30),
                    _TypeCard(
                      compact: isCompact,
                      selected: _type == CommunityPost.typeQuestion,
                      icon: Icons.help_outline_rounded,
                      title: l10n.translate('community.type.question'),
                      subtitle: l10n.translate('community.questionSubtitle'),
                      onTap: () =>
                          setState(() => _type = CommunityPost.typeQuestion),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 60),
            _Kicker(l10n.translate('community.titleLabel')),
            const SizedBox(height: 28),
            TextFormField(
              controller: _titleController,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: _brown),
              decoration: InputDecoration(
                hintText: l10n.translate('community.stitchTitleHint'),
                hintStyle: const TextStyle(
                  color: Color(0xFFB7AEA7),
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 23,
                ),
                contentPadding: EdgeInsets.all(28),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.translate('community.validation.titleRequired')
                  : null,
            ),
            const SizedBox(height: 54),
            _Kicker(l10n.translate('community.bodyLabel')),
            const SizedBox(height: 28),
            TextFormField(
              controller: _bodyController,
              minLines: 7,
              maxLines: 10,
              style: const TextStyle(fontSize: 18, height: 1.55),
              decoration: InputDecoration(
                hintText: l10n.translate('community.stitchBodyHint'),
                hintStyle: const TextStyle(
                  color: Color(0xFFAAA09A),
                  fontSize: 18,
                  height: 1.55,
                ),
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.all(28),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.translate('community.validation.bodyRequired')
                  : null,
            ),
            const SizedBox(height: 52),
            _Kicker(l10n.translate('community.tagsLabel')),
            const SizedBox(height: 28),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                ...CommunityProvider.suggestedTags.map(
                  (tag) => _TagChip(
                    label: _tagLabel(context, tag),
                    selected: _selectedTags.contains(tag),
                    onTap: () => setState(() {
                      if (_selectedTags.contains(tag)) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    }),
                  ),
                ),
                _TagChip(
                  label: l10n.translate('community.customTag'),
                  custom: true,
                  onTap: _askCustomTag,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askCustomTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.translate('community.addTag')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.translate('community.tagHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().toLowerCase()),
            child: Text(context.l10n.translate('common.create')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (tag != null && tag.isNotEmpty) setState(() => _selectedTags.add(tag));
  }

  String _name(String? name, String? email) => (name ?? '').trim().isNotEmpty
      ? name!.trim()
      : (email ?? 'User').split('@').first;
  String _tagLabel(BuildContext context, String tag) =>
      context.l10n.translateOr('community.tag.$tag', tag);
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      letterSpacing: 3.2,
      fontWeight: FontWeight.w700,
      color: Color(0xFF756159),
    ),
  );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.compact,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool compact;
  final bool selected;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: compact ? 180 : 216,
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2B1D14)
              : Colors.white.withValues(alpha: .75),
          border: Border.all(
            color: selected ? const Color(0xFF2B1D14) : const Color(0xFFE2D0AA),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                selected ? Icons.check_circle_outline : icon,
                color: selected
                    ? const Color(0xFFC19A49)
                    : const Color(0xFF756159),
                size: compact ? 24 : 30,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: selected ? Colors.white : const Color(0xFF756159),
                    size: compact ? 26 : 30,
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF2B1D14),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      height: 1.25,
                      color: selected
                          ? Colors.white70
                          : const Color(0xFF756159),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.custom = false,
  });
  final String label;
  final bool selected, custom;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2B1D14) : Colors.transparent,
        border: Border.all(
          color: custom ? const Color(0xFFC19A49) : const Color(0xFFD5B976),
          style: custom ? BorderStyle.solid : BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (custom) const Icon(Icons.add, color: Color(0xFFC19A49), size: 18),
          if (custom) const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : custom
                  ? const Color(0xFFC19A49)
                  : const Color(0xFF2B1D14),
            ),
          ),
          if (selected)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
        ],
      ),
    ),
  );
}
