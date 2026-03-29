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
import '../../widgets/sign_in_required_view.dart';

class CreateCommunityPostScreen extends StatefulWidget {
  const CreateCommunityPostScreen({super.key});

  @override
  State<CreateCommunityPostScreen> createState() =>
      _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState extends State<CreateCommunityPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  String _type = CommunityPost.typeTip;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      final canContinue = await AuthGate.ensureSignedIn(
        context,
        featureName: context.l10n.translate('community.write'),
      );
      if (!canContinue || !mounted) {
        return;
      }
    }

    final refreshedUser = context.read<AuthProvider>().user;
    if (refreshedUser == null) {
      return;
    }

    final now = DateTime.now();
    final post = CommunityPost(
      id: const Uuid().v4(),
      authorUserId: refreshedUser.uid,
      authorName: _displayNameForUser(
        refreshedUser.displayName,
        refreshedUser.email,
      ),
      type: _type,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      tags: _selectedTags.toList()..sort(),
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<CommunityProvider>().createPost(post);
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        context.l10n.translate('community.submitSuccess'),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        context.l10n.translate(
          'community.submitError',
          args: {'error': e.toString()},
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );

    if (!isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.translate('community.write'))),
        body: SignInRequiredView(
          icon: Icons.forum_outlined,
          message: l10n.translate('community.signInPrompt'),
          onSignIn: () {
            AuthGate.openSignIn(context);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('community.write')),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text(
                l10n.translate('common.save'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ResponsiveContent(
          child: ListView(
            padding: Responsive.pagePadding(context),
            children: [
              Text(
                l10n.translate('community.typeLabel'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: Text(l10n.translate('community.type.tip')),
                    selected: _type == CommunityPost.typeTip,
                    onSelected: (_) {
                      setState(() {
                        _type = CommunityPost.typeTip;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: Text(l10n.translate('community.type.question')),
                    selected: _type == CommunityPost.typeQuestion,
                    onSelected: (_) {
                      setState(() {
                        _type = CommunityPost.typeQuestion;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.translate('community.titleLabel'),
                  hintText: l10n.translate('community.titleHint'),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.translate('community.validation.titleRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: l10n.translate('community.bodyLabel'),
                  hintText: l10n.translate('community.bodyHint'),
                  alignLabelWithHint: true,
                ),
                minLines: 5,
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.translate('community.validation.bodyRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                l10n.translate('community.tagsLabel'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: CommunityProvider.suggestedTags
                    .map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(_tagLabel(context, tag)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
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

  String _tagLabel(BuildContext context, String tag) {
    return context.l10n.translateOr('community.tag.$tag', tag);
  }
}
