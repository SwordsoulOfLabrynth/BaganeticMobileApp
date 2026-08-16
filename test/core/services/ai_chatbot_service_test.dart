import 'package:flutter_test/flutter_test.dart';

import 'package:baganetic_mobile/core/services/ai_chatbot_service.dart';

void main() {
  group('AIChatbotService language guard', () {
    test('serializes an entry context without empty values', () {
      expect(const AIEntryContext.pagoda('ananda').toJson(), {
        'type': 'pagoda',
        'pagodaId': 'ananda',
      });
      expect(const AIEntryContext.global().toJson(), {'type': 'global'});
    });

    test('accepts a typed reply from the backend function', () {
      final result = AIReplyResult.fromJson({
        'reply': 'Visit Ananda Temple in the morning.',
        'createdAt': '2026-08-14T10:30:00.000Z',
        'contextSummary': {'pagodaCount': 1, 'tripCount': 0},
      });

      expect(result.reply, 'Visit Ananda Temple in the morning.');
      expect(result.createdAt, DateTime.utc(2026, 8, 14, 10, 30));
      expect(result.contextSummary, {'pagodaCount': 1, 'tripCount': 0});
    });

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
