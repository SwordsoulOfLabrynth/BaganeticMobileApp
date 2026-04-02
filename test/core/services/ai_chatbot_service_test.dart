import 'package:flutter_test/flutter_test.dart';

import 'package:baganetic_mobile/core/services/ai_chatbot_service.dart';

void main() {
  group('AIChatbotService language guard', () {
    test('detects Myanmar script', () {
      expect(AIChatbotService.containsMyanmarScript('မင်္ဂလာပါ'), isTrue);
      expect(
        AIChatbotService.containsMyanmarScript('Hello Shwezigon'),
        isFalse,
      );
    });

    test('keeps English replies intact', () {
      expect(
        AIChatbotService.sanitizeAssistantReply(
          '  Visit Ananda Temple early in the morning.  ',
        ),
        'Visit Ananda Temple early in the morning.',
      );
    });

    test('replaces Myanmar replies with English fallback', () {
      expect(
        AIChatbotService.sanitizeAssistantReply('မင်္ဂလာပါ။ ဘုရားကို သွားပါ။'),
        AIChatbotService.englishOnlyFallbackReply,
      );
      expect(
        AIChatbotService.sanitizeAssistantReply(
          'Best time is sunrise. မနက်စောစော သွားပါ။',
        ),
        AIChatbotService.englishOnlyFallbackReply,
      );
    });
  });
}
