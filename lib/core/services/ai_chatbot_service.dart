import 'package:google_generative_ai/google_generative_ai.dart';

import 'logger.dart';

class AIPagodaContext {
  final String id;
  final String name;
  final String category;
  final String summary;
  final String? bestTime;
  final String? openingHours;
  final String? location;

  const AIPagodaContext({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    this.bestTime,
    this.openingHours,
    this.location,
  });

  String get searchableText {
    return [
      id,
      name,
      category,
      summary,
      bestTime ?? '',
      openingHours ?? '',
      location ?? '',
    ].join(' ').toLowerCase();
  }
}

class AIChatMessage {
  static const String roleUser = 'user';
  static const String roleAssistant = 'assistant';

  final String role;
  final String text;
  final DateTime createdAt;

  const AIChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  bool get isUser => role == roleUser;

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      role: json['role'] as String? ?? roleAssistant,
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AIChatbotService {
  AIChatbotService()
    : _model = _apiKey.isEmpty
          ? null
          : GenerativeModel(
              model: _modelName,
              apiKey: _apiKey,
              generationConfig: GenerationConfig(
                temperature: 0.2,
                topP: 0.9,
                maxOutputTokens: 700,
              ),
            );

  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _modelName = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.0-flash',
  );
  static const int _historyLimit = 12;

  final GenerativeModel? _model;

  Future<String> generateReply({
    required String prompt,
    required List<AIChatMessage> history,
    String? languageCode,
    List<AIPagodaContext> pagodaContext = const [],
  }) async {
    final model = _model;
    if (model == null) {
      return _fallbackReply(
        prompt,
        languageCode: languageCode,
        pagodaContext: pagodaContext,
      );
    }

    try {
      final chat = model.startChat(history: _toGeminiHistory(history));
      final response = await chat.sendMessage(
        Content.text(
          _buildGuidedPrompt(
            prompt,
            languageCode: languageCode,
            pagodaContext: pagodaContext,
          ),
        ),
      );
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return _fallbackReply(
          prompt,
          languageCode: languageCode,
          pagodaContext: pagodaContext,
        );
      }
      return text;
    } catch (e, stackTrace) {
      Logger.error(
        'AI chatbot request failed, using fallback reply',
        e,
        stackTrace,
      );
      return _fallbackReply(
        prompt,
        languageCode: languageCode,
        pagodaContext: pagodaContext,
      );
    }
  }

  List<Content> _toGeminiHistory(List<AIChatMessage> history) {
    final start = history.length > _historyLimit
        ? history.length - _historyLimit
        : 0;
    final trimmed = history.sublist(start);

    return trimmed
        .map((message) {
          final role = message.isUser ? 'user' : 'model';
          return Content(role, [TextPart(message.text)]);
        })
        .toList(growable: false);
  }

  String _buildGuidedPrompt(
    String userPrompt, {
    String? languageCode,
    List<AIPagodaContext> pagodaContext = const [],
  }) {
    final relevantContext = _selectRelevantContext(userPrompt, pagodaContext);
    final knowledge = relevantContext
        .map((p) {
          final parts = <String>[
            '- ${p.name} (${p.category}, id: ${p.id})',
            '  Summary: ${p.summary}',
          ];
          if ((p.bestTime ?? '').isNotEmpty) {
            parts.add('  Best time: ${p.bestTime}');
          }
          if ((p.openingHours ?? '').isNotEmpty) {
            parts.add('  Opening hours: ${p.openingHours}');
          }
          if ((p.location ?? '').isNotEmpty) {
            parts.add('  Location: ${p.location}');
          }
          return parts.join('\n');
        })
        .join('\n');
    final languageInstruction = _resolveLanguageInstruction(
      userPrompt,
      languageCode: languageCode,
    );

    return '''
You are Baganetic's in-app travel assistant for Bagan pagodas.
Your job:
- Give practical route plans (1-day/half-day/multi-stop).
- Give cultural etiquette and temple behavior guidance.
- Suggest best visit timing, sunrise/sunset windows, and pacing.
- When asked for distances/time, give estimates and mention they are approximate.
- If unsure, say uncertainty clearly and offer a safe alternative.

Style rules:
- Keep answers structured and useful (short headings or bullets).
- Match the user's language.
- Keep response concise unless user asks for detail.

Known pagodas in app data:
${knowledge.isEmpty ? '- (not provided in this request)' : knowledge}

User message:
$userPrompt

Response language:
$languageInstruction
''';
  }

  String _resolveLanguageInstruction(String prompt, {String? languageCode}) {
    if (_isMyanmarText(prompt) || languageCode == 'my') {
      return 'Burmese (Myanmar).';
    }
    return 'English.';
  }

  String _fallbackReply(
    String prompt, {
    String? languageCode,
    List<AIPagodaContext> pagodaContext = const [],
  }) {
    final useMyanmar = _isMyanmarText(prompt) || languageCode == 'my';
    final input = prompt.toLowerCase();
    final mentionedPagodas = _findMentionedPagodas(prompt, pagodaContext);

    if (_isRouteIntent(input)) {
      if (mentionedPagodas.length >= 2) {
        final names = mentionedPagodas.take(4).map((p) => p.name).toList();
        if (useMyanmar) {
          return [
            'အကြံပြုလမ်းကြောင်း:',
            names.map((name) => '- $name').join('\n'),
            'အကြံပြုချက်: မနက်စောစော စပြီး တစ်နေရာလျှင် ၄၅-၆၀ မိနစ်၊ နေရာကြား ၁၀-၁၅ မိနစ် ချန်ပါ။',
          ].join('\n');
        }
        return [
          'Suggested route order:',
          names.map((name) => '- $name').join('\n'),
          'Tip: start early, keep 45-60 minutes per stop, and 10-15 minutes transfer buffer.',
        ].join('\n');
      }

      if (mentionedPagodas.isNotEmpty) {
        final seed = mentionedPagodas.first;
        final extras = _selectRelevantContext(
          seed.searchableText,
          pagodaContext,
        ).where((p) => p.id != seed.id).take(2).toList();
        final route = [seed, ...extras].map((p) => p.name).toList();
        if (useMyanmar) {
          return [
            'ဤနေရာကို အခြေခံတဲ့ ခရီးစဉ်တို:',
            route.map((name) => '- $name').join('\n'),
            'မနက် ၆:၀၀-၁၁:၀၀ သို့မဟုတ် ညနေ ၃:၃၀-နေဝင်ချိန်ကို ရွေးပါ။',
          ].join('\n');
        }
        return [
          'Short route built around ${seed.name}:',
          route.map((name) => '- $name').join('\n'),
          'Best window: 6:00-11:00 AM or 3:30 PM to sunset.',
        ].join('\n');
      }

      final highlights = pagodaContext.take(3).map((p) => p.name).toList();
      if (highlights.isNotEmpty) {
        if (useMyanmar) {
          return [
            'စတင်ရန် အကြံပြု highlight စေတီများ:',
            highlights.map((name) => '- $name').join('\n'),
            'သင့်စတင်ရာနေရာပြောပါက ပိုတိကျတဲ့လမ်းကြောင်းပေးမယ်။',
          ].join('\n');
        }
        return [
          'Recommended highlights to start with:',
          highlights.map((name) => '- $name').join('\n'),
          'Share your starting point and I can create a tighter route.',
        ].join('\n');
      }
    }

    if (_isCompareIntent(input) && mentionedPagodas.length >= 2) {
      final a = mentionedPagodas[0];
      final b = mentionedPagodas[1];
      if (useMyanmar) {
        return [
          '${a.name} နှင့် ${b.name} နှိုင်းယှဉ်ချက်:',
          '- ${a.name}: ${_safeFact(a.bestTime, fallback: "အချိန်အချက်အလက် မရသေးပါ")}',
          '- ${b.name}: ${_safeFact(b.bestTime, fallback: "အချိန်အချက်အလက် မရသေးပါ")}',
          'အသေးစိတ်လိုပါက ဖွင့်ချိန်၊ တည်နေရာ၊ သမိုင်းကို သီးသန့်မေးနိုင်ပါတယ်။',
        ].join('\n');
      }
      return [
        'Quick comparison: ${a.name} vs ${b.name}',
        '- ${a.name}: ${_safeFact(a.bestTime, fallback: "best-time data unavailable")}',
        '- ${b.name}: ${_safeFact(b.bestTime, fallback: "best-time data unavailable")}',
        'Ask for a focused comparison (hours, location, history, vibe) if needed.',
      ].join('\n');
    }

    if (_isHoursIntent(input) && mentionedPagodas.isNotEmpty) {
      final p = mentionedPagodas.first;
      final hours = _safeFact(
        p.openingHours,
        fallback: useMyanmar
            ? 'ဖွင့်ချိန် မရသေးပါ'
            : 'Opening hours not available.',
      );
      return useMyanmar
          ? '${p.name} ဖွင့်ချိန်: $hours'
          : '${p.name} opening hours: $hours';
    }

    if (_isLocationIntent(input) && mentionedPagodas.isNotEmpty) {
      final p = mentionedPagodas.first;
      final location = _safeFact(
        p.location,
        fallback: useMyanmar
            ? 'တည်နေရာ မရသေးပါ'
            : 'Location data not available.',
      );
      return useMyanmar
          ? '${p.name} တည်နေရာ: $location'
          : '${p.name} location: $location';
    }

    if (_isTimingIntent(input) && mentionedPagodas.isNotEmpty) {
      final p = mentionedPagodas.first;
      final bestTime = _safeFact(
        p.bestTime,
        fallback: useMyanmar
            ? 'အချိန်အကြံပြုချက် မရသေးပါ'
            : 'Best-time data not available.',
      );
      return useMyanmar
          ? '${p.name} သွားလည်ရန် အချိန်အကြံပြုချက်: $bestTime'
          : 'Best time for ${p.name}: $bestTime';
    }

    final directMatch = _findBestDirectMatch(prompt, pagodaContext);
    if (directMatch != null) {
      return _formatPagodaQuickInfo(directMatch, useMyanmar: useMyanmar);
    }

    if (input.contains('sunrise') || input.contains('sunset')) {
      return useMyanmar
          ? 'နေထွက်/နေဝင် ကြည့်မယ်ဆိုရင် ၂၀-၃၀ မိနစ် စောစောရောက်ပြီး မြင့်မြင်ကွင်းရှိနေရာကို ရွေးပါ။ အရင်ဆုံး လုံခြုံရေးနှင့် ခွင့်ပြုချက်ကို သေချာစစ်ပါ။'
          : 'For sunrise/sunset in Bagan, arrive 20-30 minutes early and use permitted elevated viewpoints.';
    }
    if (input.contains('dress') || input.contains('etiquette')) {
      return useMyanmar
          ? 'ဘုရားစေတီဝင်ရာတွင် ပခုံးနှင့် ဒူးဖုံးသောအဝတ်အစား ဝတ်ပါ၊ ဝင်ခွင့်ဧရိယာတွင် ဖိနပ်/ခြေအိတ်ချွတ်ပါ၊ အသံကိုညှိ၍ လေးစားစွာနေပါ။'
          : 'At pagodas, wear modest clothing, remove shoes/socks in sacred areas, and keep your voice low.';
    }
    if (input.contains('route') ||
        input.contains('trip') ||
        input.contains('plan')) {
      return useMyanmar
          ? 'လမ်းကြောင်းစီစဉ်ရာမှာ နီးစပ်ရာစေတီတွေကို ဇုန်လိုက်စုပါ၊ မနက်စောစောစတင်ပါ၊ တစ်နေရာနှင့်တစ်နေရာကြား ၁၀-၁၅ မိနစ် buffer ထားပါ။'
          : 'Group nearby pagodas by zone, start early, and keep 10-15 minutes of buffer between stops.';
    }
    if (input.contains('weather') || input.contains('best time')) {
      return useMyanmar
          ? 'သွားလည်ဖို့ အဆင်ပြေတာက မနက်စောစောနှင့် ညနေဖြစ်ပါတယ်။ နေ့လယ်ပိုင်းမှာ ရေ၊ ထီး/နေကာနှင့် နေရောင်ကာကွယ်ရေး ဆောင်ထားပါ။'
          : 'Early morning and late afternoon are most comfortable. Carry water and sun protection at midday.';
    }
    if (input.contains('ananda') ||
        input.contains('dhammayangyi') ||
        input.contains('shwezigon')) {
      return useMyanmar
          ? 'ဒီနေရာগুলোက highlight ကောင်းတွေပါ။ ခရီးစဉ်တိုတစ်ခုအတွက် Ananda -> Dhammayangyi -> Shwezigon လိုစီစဉ်ပြီး ရိုက်ကူး/အနားယူချိန် ထည့်ပါ။'
          : 'Great highlights. A balanced short route is Ananda -> Dhammayangyi -> Shwezigon with photo/rest breaks.';
    }

    return useMyanmar
        ? 'လမ်းကြောင်း၊ အချိန်ဇယား၊ အပြုအမူစည်းကမ်းနှင့် ခရီးစဉ်အကြံပြုချက်ပေးနိုင်ပါတယ်။\nဥပမာ - "Ananda နဲ့ Shwezigon တစ်နေ့ခရီးစီစဉ်ပေး", "Dhammayangyi ဖွင့်ချိန်ဘာလဲ"'
        : 'I can help with route planning, timing, etiquette, and itinerary suggestions.\nTry: "Plan a one-day route for Ananda and Shwezigon" or "What are Dhammayangyi opening hours?"';
  }

  bool _isMyanmarText(String text) {
    return RegExp(r'[\u1000-\u109F]').hasMatch(text);
  }

  AIPagodaContext? _findBestDirectMatch(
    String prompt,
    List<AIPagodaContext> contexts,
  ) {
    if (contexts.isEmpty) {
      return null;
    }
    final promptLower = prompt.toLowerCase();
    AIPagodaContext? best;
    var bestScore = 0;
    for (final context in contexts) {
      var score = 0;
      final nameLower = context.name.toLowerCase();
      final idLower = context.id.toLowerCase();
      if (promptLower.contains(nameLower)) {
        score += 10;
      }
      if (promptLower.contains(idLower)) {
        score += 8;
      }
      if (promptLower.contains(nameLower.split(' ').first)) {
        score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = context;
      }
    }
    if (bestScore < 4) {
      return null;
    }
    return best;
  }

  List<AIPagodaContext> _selectRelevantContext(
    String prompt,
    List<AIPagodaContext> all,
  ) {
    if (all.isEmpty) {
      return const [];
    }
    final promptLower = prompt.toLowerCase();
    final tokens = _extractKeywords(promptLower);
    if (tokens.isEmpty) {
      return all.take(8).toList(growable: false);
    }

    final scored = all
        .map((p) {
          var score = 0;
          final searchable = p.searchableText;
          if (promptLower.contains(p.name.toLowerCase())) {
            score += 8;
          }
          if (promptLower.contains(p.id.toLowerCase())) {
            score += 6;
          }
          for (final token in tokens) {
            if (token.length < 3) continue;
            if (searchable.contains(token)) {
              score += 1;
            }
          }
          return (context: p, score: score);
        })
        .toList(growable: false);

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.where((e) => e.score > 0).take(6).map((e) => e.context);
    if (top.isEmpty) {
      return all.take(6).toList(growable: false);
    }
    return top.toList(growable: false);
  }

  Set<String> _extractKeywords(String input) {
    final normalized = input
        .replaceAll(RegExp(r'[^a-z0-9\u1000-\u109f\s-]'), ' ')
        .replaceAll('-', ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.trim())
        .toSet();

    const stopWords = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'to',
      'for',
      'of',
      'in',
      'on',
      'and',
      'or',
      'with',
      'me',
      'about',
      'please',
      'want',
      'need',
      'how',
      'what',
      'where',
      'when',
      'can',
      'you',
    };

    words.removeWhere((w) => stopWords.contains(w));
    return words;
  }

  List<AIPagodaContext> _findMentionedPagodas(
    String prompt,
    List<AIPagodaContext> contexts,
  ) {
    if (contexts.isEmpty) {
      return const [];
    }
    final promptLower = prompt.toLowerCase();
    final scored = <({AIPagodaContext context, int score, int index})>[];
    for (final context in contexts) {
      var score = 0;
      var index = 1 << 30;
      final nameLower = context.name.toLowerCase();
      final idLower = context.id.toLowerCase();

      final nameIndex = promptLower.indexOf(nameLower);
      if (nameIndex >= 0) {
        score += 10;
        index = nameIndex;
      }

      final idIndex = promptLower.indexOf(idLower);
      if (idIndex >= 0) {
        score += 8;
        if (idIndex < index) {
          index = idIndex;
        }
      }

      for (final token in nameLower.split(RegExp(r'\s+'))) {
        if (token.length < 4) {
          continue;
        }
        final tokenIndex = promptLower.indexOf(token);
        if (tokenIndex >= 0) {
          score += 2;
          if (tokenIndex < index) {
            index = tokenIndex;
          }
        }
      }

      if (score >= 3) {
        scored.add((context: context, score: score, index: index));
      }
    }

    scored.sort((a, b) {
      final indexCompare = a.index.compareTo(b.index);
      if (indexCompare != 0) {
        return indexCompare;
      }
      return b.score.compareTo(a.score);
    });

    return scored.map((e) => e.context).toList(growable: false);
  }

  bool _isRouteIntent(String input) {
    return _containsAny(input, const [
      'route',
      'trip',
      'plan',
      'itinerary',
      'schedule',
      'one day',
      'half day',
      'လမ်းကြောင်း',
      'ခရီးစဉ်',
      'အစီအစဉ်',
      'အချိန်ဇယား',
      'တစ်နေ့',
    ]);
  }

  bool _isCompareIntent(String input) {
    return _containsAny(input, const [
      'compare',
      'difference',
      'vs',
      'versus',
      'which',
      'နှိုင်းယှဉ်',
      'ကွာခြား',
    ]);
  }

  bool _isTimingIntent(String input) {
    return _containsAny(input, const [
      'best time',
      'when to visit',
      'sunrise',
      'sunset',
      'အချိန်',
      'ဘယ်ချိန်',
      'နေထွက်',
      'နေဝင်',
    ]);
  }

  bool _isHoursIntent(String input) {
    return _containsAny(input, const [
      'opening hour',
      'opening',
      'open',
      'close',
      'hours',
      'ဖွင့်ချိန်',
      'ပိတ်ချိန်',
    ]);
  }

  bool _isLocationIntent(String input) {
    return _containsAny(input, const [
      'location',
      'where',
      'near',
      'တည်နေရာ',
      'ဘယ်မှာ',
      'အနီး',
    ]);
  }

  bool _containsAny(String input, List<String> keywords) {
    for (final keyword in keywords) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  String _safeFact(String? value, {required String fallback}) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatPagodaQuickInfo(
    AIPagodaContext pagoda, {
    required bool useMyanmar,
  }) {
    final summary = pagoda.summary.trim();
    final bestTime = (pagoda.bestTime ?? '').trim();
    final openingHours = (pagoda.openingHours ?? '').trim();
    final location = (pagoda.location ?? '').trim();

    if (useMyanmar) {
      return [
        '${pagoda.name} အကြောင်း အကျဉ်းချုပ်:',
        if (summary.isNotEmpty) summary,
        if (bestTime.isNotEmpty) 'အကောင်းဆုံးအချိန်: $bestTime',
        if (openingHours.isNotEmpty) 'ဖွင့်ချိန်: $openingHours',
        if (location.isNotEmpty) 'တည်နေရာ: $location',
      ].join('\n');
    }

    return [
      'Quick info for ${pagoda.name}:',
      if (summary.isNotEmpty) summary,
      if (bestTime.isNotEmpty) 'Best time: $bestTime',
      if (openingHours.isNotEmpty) 'Opening hours: $openingHours',
      if (location.isNotEmpty) 'Location: $location',
    ].join('\n');
  }
}
