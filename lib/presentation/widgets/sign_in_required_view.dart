import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/responsive.dart';

class SignInRequiredView extends StatelessWidget {
  final String message;
  final VoidCallback onSignIn;
  final String? title;
  final IconData icon;

  const SignInRequiredView({
    super.key,
    required this.message,
    required this.onSignIn,
    this.title,
    this.icon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: Responsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 84, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                title ?? l10n.translate('auth.signInRequiredTitle'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: Text(l10n.translate('auth.signIn')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
