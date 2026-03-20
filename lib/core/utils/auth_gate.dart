import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/auth_provider.dart';
import '../localization/app_localizations.dart';

class AuthGate {
  static bool isSignedIn(BuildContext context) {
    return context.read<AuthProvider>().user != null;
  }

  static Future<bool> openSignIn(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed('/login');
    if (!context.mounted) {
      return false;
    }
    return result == true || isSignedIn(context);
  }

  static Future<bool> ensureSignedIn(
    BuildContext context, {
    required String featureName,
  }) async {
    if (isSignedIn(context)) {
      return true;
    }

    final l10n = context.l10n;
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.translate('auth.signInRequiredTitle')),
          content: Text(
            l10n.translate(
              'auth.signInRequiredBody',
              args: {'feature': featureName},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.translate('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.translate('auth.signIn')),
            ),
          ],
        );
      },
    );

    if (shouldSignIn != true || !context.mounted) {
      return false;
    }

    return openSignIn(context);
  }
}
