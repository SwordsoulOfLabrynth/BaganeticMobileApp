import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/chat_errors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/logger.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/repositories/chat_repository.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final l10n = context.l10n;
    final name = _nameController.text.trim();

    try {
      final groupId = await context.read<ChatRepository>().createGroup(name);
      if (!mounted) return;
      Navigator.pop(context, {'id': groupId, 'name': name});
    } catch (e) {
      Logger.error('CreateGroupScreen: failed to create group', e);
      if (!mounted) return;
      Helpers.showSnackBar(context, _buildErrorMessage(l10n, e), isError: true);
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _buildErrorMessage(AppLocalizations l10n, Object error) {
    if (error is AuthError) {
      return l10n.translate('chat.authRequired');
    }
    if (error is NetworkError) {
      return l10n.translate('auth.networkRequestFailed');
    }
    if (error is PermissionError && error.message.isNotEmpty) {
      return error.message;
    }
    if (error is ValidationError && error.message.isNotEmpty) {
      return error.message;
    }
    return l10n.translate('chat.createFailed');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('chat.createGroupTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.translate('chat.groupNameLabel'),
                  hintText: l10n.translate('chat.groupNameHint'),
                ),
                textInputAction: TextInputAction.done,
                maxLength: 50,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return l10n.translate('chat.groupNameRequired');
                  }
                  if (trimmed.length < 3) {
                    return l10n.translate('chat.groupNameTooShort');
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _createGroup(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createGroup,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.translate('chat.createGroup')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
