import 'package:http/http.dart' as http;
import 'dart:convert';

abstract class LLMProvider {
  Future<String> chat(String message, {String? context});
}

class LLMService {
  final String apiKey;
  final String provider; // 'openai', 'gemini', 'claude'
  
  LLMService({
    required this.apiKey,
    required this.provider,
  });
  
  Future<String> chat(String message, {String? context}) async {
    switch (provider.toLowerCase()) {
      case 'openai':
        return await _chatOpenAI(message, context);
      case 'gemini':
        return await _chatGemini(message, context);
      case 'claude':
        return await _chatClaude(message, context);
      default:
        throw Exception('Unsupported provider: $provider');
    }
  }
  
  Future<String> _chatOpenAI(String message, String? context) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final messages = [
      if (context != null)
        {
          'role': 'system',
          'content': 'You are a helpful tour guide assistant for Bagan pagodas. Use the following context: $context',
        },
      {
        'role': 'user',
        'content': message,
      },
    ];
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('OpenAI API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get response from OpenAI: $e');
    }
  }
  
  Future<String> _chatGemini(String message, String? context) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey'
    );
    
    final prompt = context != null
        ? 'Context: $context\n\nUser: $message'
        : message;
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get response from Gemini: $e');
    }
  }
  
  Future<String> _chatClaude(String message, String? context) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    
    final systemPrompt = context != null
        ? 'You are a helpful tour guide assistant for Bagan pagodas. Context: $context'
        : 'You are a helpful tour guide assistant for Bagan pagodas.';
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 500,
          'system': systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': message,
            },
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        throw Exception('Claude API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get response from Claude: $e');
    }
  }
}
