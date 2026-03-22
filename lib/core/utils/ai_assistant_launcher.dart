import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'auth_gate.dart';
import '../services/ai_chatbot_service.dart';
import '../../presentation/screens/chat/chat_screen.dart';

class AIAssistantLauncher {
  static Future<void> open(
    BuildContext context, {
    AIEntryContext entryContext = const AIEntryContext.global(),
  }) async {
    final canOpen = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('chat.title'),
    );
    if (!canOpen || !context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(entryContext: entryContext)),
    );
  }
}
