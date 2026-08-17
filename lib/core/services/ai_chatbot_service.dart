import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/trip_model.dart';
import 'firestore_instance.dart';
import 'logger.dart';

enum AIContextType { global, pagoda, trip }

class AIEntryContext {
  final AIContextType type;
  final String? pagodaId;
  final String? tripId;

  const AIEntryContext({required this.type, this.pagodaId, this.tripId});

  const AIEntryContext.global()
    : type = AIContextType.global,
      pagodaId = null,
      tripId = null;

  const AIEntryContext.pagoda(String this.pagodaId)
    : type = AIContextType.pagoda,
      tripId = null;

  const AIEntryContext.trip(String this.tripId)
    : type = AIContextType.trip,
      pagodaId = null;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if ((pagodaId ?? '').isNotEmpty) 'pagodaId': pagodaId,
      if ((tripId ?? '').isNotEmpty) 'tripId': tripId,
    };
  }
}

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'summary': summary,
      'bestTime': bestTime,
      'openingHours': openingHours,
      'location': location,
    };
  }
}

class AITripStopContext {
  final String pagodaId;
  final String pagodaName;
  final String? notes;

  const AITripStopContext({
    required this.pagodaId,
    required this.pagodaName,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'pagodaId': pagodaId,
      'pagodaName': pagodaName,
      if ((notes ?? '').isNotEmpty) 'notes': notes,
    };
  }
}

class AITripContext {
  final String id;
  final String name;
  final String? description;
  final List<AITripStopContext> stops;

  const AITripContext({
    required this.id,
    required this.name,
    this.description,
    this.stops = const [],
  });

  factory AITripContext.fromTrip(Trip trip) {
    return AITripContext(
      id: trip.id,
      name: trip.name,
      description: trip.description,
      stops: trip.stops
          .map(
            (stop) => AITripStopContext(
              pagodaId: stop.pagodaId,
              pagodaName: stop.pagodaName,
              notes: stop.notes,
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if ((description ?? '').isNotEmpty) 'description': description,
      'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    };
  }
}

class AICommunityPostContext {
  final String id;
  final String authorName;
  final String type;
  final String title;
  final String body;
  final List<String> tags;
  final DateTime createdAt;
  final int upvoteCount;
  final int commentCount;

  const AICommunityPostContext({
    required this.id,
    required this.authorName,
    required this.type,
    required this.title,
    required this.body,
    this.tags = const [],
    required this.createdAt,
    this.upvoteCount = 0,
    this.commentCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'type': type,
      'title': title,
      'body': body,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'upvoteCount': upvoteCount,
      'commentCount': commentCount,
    };
  }
}

class AIChatMessage {
  static const String roleUser = 'user';
  static const String roleAssistant = 'assistant';

  final String id;
  final String role;
  final String text;
  final DateTime createdAt;

  const AIChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  bool get isUser => role == roleUser;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AIChatMessage.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AIChatMessage(
      id: doc.id,
      role: data['role'] as String? ?? roleAssistant,
      text: data['text'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  factory AIChatMessage.fromLocalJson(Map<String, dynamic> data) {
    return AIChatMessage(
      id: data['id'] as String? ?? '',
      role: data['role'] as String? ?? roleAssistant,
      text: data['text'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class AIReplyResult {
  final String reply;
  final DateTime createdAt;
  final Map<String, int> contextSummary;

  const AIReplyResult({
    required this.reply,
    required this.createdAt,
    required this.contextSummary,
  });

  factory AIReplyResult.fromJson(Map<String, dynamic> json) {
    final summary = <String, int>{};
    final rawSummary = json['contextSummary'];
    if (rawSummary is Map) {
      for (final entry in rawSummary.entries) {
        summary[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return AIReplyResult(
      reply: json['reply'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      contextSummary: summary,
    );
  }
}

class AIChatbotService {
  static const String _functionRegion = String.fromEnvironment(
    'AI_FUNCTION_REGION',
    defaultValue: 'asia-southeast1',
  );
  static const String _functionName = 'generateAiReply';
  static const String _directNvidiaApiKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
  );
  static const String _nvidiaChatEndpoint =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String _nvidiaModel = 'meta/llama-3.1-8b-instruct';
  // The public Worker URL is safe to include in the client; the NVIDIA key
  // remains server-side in Cloudflare. A dart-define can still override this
  // for staging or local development.
  static const String _proxyUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue:
        'https://baganetic-ai-proxy.kyawzayyahein-mdy.workers.dev/v1/chat',
  );
  static const int _historyLimit = 12;
  static const String englishOnlyFallbackReply =
      'I can help in English only. Please ask your question again in English.';
  static final RegExp _myanmarScriptPattern = RegExp(r'[\u1000-\u109F]');

  AIChatbotService({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    FirebaseFunctions? functions,
    DatabaseService? databaseService,
  }) : _firestoreOverride = firestore,
       _authOverride = auth,
       _functionsOverride = functions,
       _localDb = databaseService ?? DatabaseService();

  final FirebaseFirestore? _firestoreOverride;
  final firebase_auth.FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  final DatabaseService _localDb;

  FirebaseFirestore? get _firestore =>
      _firestoreOverride ?? FirestoreInstance.instanceOrNull;

  firebase_auth.FirebaseAuth? get _auth {
    if (_authOverride != null) {
      return _authOverride;
    }
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return firebase_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFunctions? get _functions {
    if (_functionsOverride != null) {
      return _functionsOverride;
    }
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return FirebaseFunctions.instanceFor(region: _functionRegion);
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => _auth?.currentUser?.uid;
  Uri? get _proxyEndpoint {
    final endpoint = Uri.tryParse(_proxyUrl.trim());
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'https' && endpoint.scheme != 'http')) {
      return null;
    }
    return endpoint;
  }

  bool get isConfigured =>
      _hasDirectNvidiaDemoKey || _proxyEndpoint != null || _functions != null;

  bool get _hasDirectNvidiaDemoKey => _directNvidiaApiKey.trim().isNotEmpty;

  Stream<List<AIChatMessage>> messageStream() {
    final uid = currentUserId;
    final firestore = _firestore;
    if (uid == null || firestore == null) {
      return Stream.value(const []);
    }

    return firestore
        .collection(AppConstants.users)
        .doc(uid)
        .collection(AppConstants.aiChatMessages)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AIChatMessage.fromFirestore)
              .where((message) => message.text.trim().isNotEmpty)
              .toList(growable: false),
        );
  }

  Future<List<AIChatMessage>> localFallbackMessages() async {
    final uid = currentUserId;
    if (uid == null) {
      return const [];
    }
    return _loadLocalFallbackMessages(uid);
  }

  Future<AIReplyResult> generateReply({
    required String prompt,
    required String requestId,
    required List<AIPagodaContext> pagodaContext,
    List<AICommunityPostContext> communityContext = const [],
    AIEntryContext entryContext = const AIEntryContext.global(),
    AITripContext? tripContext,
    List<AIChatMessage>? historyOverride,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Sign in is required to use the AI assistant.');
    }
    if (_functions == null && _proxyEndpoint == null && !_hasDirectNvidiaDemoKey) {
      throw StateError('The AI service is not available in this build.');
    }

    try {
      final history = historyOverride != null
          ? _normalizeHistory(historyOverride)
          : await _loadRecentHistorySafe(uid);
      await _writeMessageSafe(
        uid,
        AIChatMessage(
          id: requestId,
          role: AIChatMessage.roleUser,
          text: prompt,
          createdAt: DateTime.now(),
        ),
        entryContext: entryContext,
        requestId: requestId,
      );

      final result = await _requestBackendReply(
        prompt: prompt,
        history: history,
        pagodaContext: pagodaContext,
        communityContext: communityContext,
        entryContext: entryContext,
        tripContext: tripContext,
      );
      final assistantMessage = AIChatMessage(
        id: '${requestId}_assistant',
        role: AIChatMessage.roleAssistant,
        text: result.reply,
        createdAt: result.createdAt,
      );
      await _writeMessageSafe(
        uid,
        assistantMessage,
        entryContext: entryContext,
        requestId: requestId,
      );
      return result;
    } catch (e, stackTrace) {
      Logger.error('Unexpected AI backend request failure', e, stackTrace);
      rethrow;
    }
  }

  Future<AIReplyResult> _requestBackendReply({
    required String prompt,
    required List<AIChatMessage> history,
    required List<AIPagodaContext> pagodaContext,
    required List<AICommunityPostContext> communityContext,
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
  }) async {
    final relevantPagodas = _selectRelevantPagodas(
      prompt: prompt,
      pagodas: pagodaContext,
      entryContext: entryContext,
      tripContext: tripContext,
    );
    final relevantCommunityPosts = _selectRelevantCommunityPosts(
      prompt: prompt,
      communityPosts: communityContext,
      relevantPagodas: relevantPagodas,
      entryContext: entryContext,
      tripContext: tripContext,
    );
    final payload = <String, dynamic>{
      'prompt': prompt,
      'history': history
          .map((message) => {'role': message.role, 'text': message.text})
          .toList(growable: false),
      'context': {
        'entry': entryContext.toJson(),
        'pagodas': relevantPagodas
            .map((pagoda) => pagoda.toJson())
            .toList(growable: false),
        'trip': tripContext?.toJson(),
        'communityPosts': relevantCommunityPosts
            .map((post) => post.toJson())
            .toList(growable: false),
      },
    };
    if (_hasDirectNvidiaDemoKey) {
      return _requestDirectNvidiaReply(payload);
    }

    final proxy = _proxyEndpoint;
    if (proxy != null) {
      return _requestProxyReply(proxy, payload);
    }

    final functions = _functions;
    if (functions == null) {
      throw StateError('The AI service is not available in this build.');
    }
    final response = await functions
        .httpsCallable(
          _functionName,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>(payload);

    final result = AIReplyResult.fromJson(response.data);
    final reply = _sanitizeAssistantReply(result.reply);
    if (reply.isEmpty) {
      throw StateError('The AI service returned no reply.');
    }
    return AIReplyResult(
      reply: reply,
      createdAt: result.createdAt,
      contextSummary: result.contextSummary,
    );
  }

  Future<AIReplyResult> _requestDirectNvidiaReply(
    Map<String, dynamic> payload,
  ) async {
    final context = payload['context'] as Map<String, dynamic>? ?? const {};
    final history = (payload['history'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (message) => {
            'role': message['role'] == AIChatMessage.roleAssistant
                ? 'assistant'
                : 'user',
            'content': message['text']?.toString().trim() ?? '',
          },
        )
        .where((message) => (message['content'] as String).isNotEmpty)
        .toList(growable: false);

    late http.Response response;
    Object? lastConnectionError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        response = await http
            .post(
              Uri.parse(_nvidiaChatEndpoint),
              headers: {
                'Authorization': 'Bearer ${_directNvidiaApiKey.trim()}',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'model': _nvidiaModel,
                'temperature': 0.2,
                'top_p': 0.9,
                'max_tokens': 700,
                'messages': [
                  {'role': 'system', 'content': _directSystemPrompt(context)},
                  ...history,
                  {'role': 'user', 'content': payload['prompt']},
                ],
              }),
            )
            .timeout(const Duration(seconds: 60));
        lastConnectionError = null;
        break;
      } on TimeoutException catch (error) {
        lastConnectionError = error;
      } on http.ClientException catch (error) {
        lastConnectionError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    if (lastConnectionError != null) {
      throw lastConnectionError;
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'The AI provider could not complete this request. Please try again later.',
      );
    }
    final choices = data['choices'];
    final firstChoice = choices is List && choices.isNotEmpty
        ? choices.first
        : null;
    final message = firstChoice is Map ? firstChoice['message'] : null;
    final rawReply = message is Map
        ? message['content']?.toString() ?? ''
        : '';
    final reply = _sanitizeAssistantReply(rawReply);
    if (reply.isEmpty) {
      throw StateError('The AI provider returned no reply.');
    }
    return AIReplyResult(
      reply: reply,
      createdAt: DateTime.now(),
      contextSummary: {
        'pagodaCount': (context['pagodas'] as List?)?.length ?? 0,
        'tripCount': context['trip'] == null ? 0 : 1,
        'communityPostCount': (context['communityPosts'] as List?)?.length ?? 0,
      },
    );
  }

  String _directSystemPrompt(Map<String, dynamic> context) {
    final pagodas = (context['pagodas'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .take(8)
        .map((pagoda) {
          final name = pagoda['name']?.toString().trim() ?? '';
          final category = pagoda['category']?.toString().trim() ?? '';
          final summary = pagoda['summary']?.toString().trim() ?? '';
          return name.isEmpty
              ? ''
              : '- $name${category.isEmpty ? '' : ' ($category)'}: $summary';
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
    return [
      "You are Baganetic's in-app travel assistant for Bagan pagodas.",
      'Stay inside the Bagan travel domain and answer concisely in English.',
      'Do not invent facts. Treat community posts as unverified traveler reports.',
      'Relevant pagoda context:',
      pagodas.isEmpty ? '- No pagoda context supplied.' : pagodas,
    ].join('\n');
  }

  Future<AIReplyResult> _requestProxyReply(
    Uri endpoint,
    Map<String, dynamic> payload,
  ) async {
    final token = await _auth?.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to use the AI assistant.');
    }
    late http.Response response;
    Object? lastConnectionError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        response = await http
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 60));
        lastConnectionError = null;
        break;
      } on TimeoutException catch (error) {
        lastConnectionError = error;
      } on http.ClientException catch (error) {
        lastConnectionError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    if (lastConnectionError != null) {
      throw lastConnectionError;
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['error']?.toString().trim();
      throw StateError(
        message == null || message.isEmpty
            ? 'The AI service is temporarily unavailable. Please try again later.'
            : message,
      );
    }

    final result = AIReplyResult.fromJson(data);
    final reply = _sanitizeAssistantReply(result.reply);
    if (reply.isEmpty) {
      throw StateError('The AI service returned no reply.');
    }
    return AIReplyResult(
      reply: reply,
      createdAt: result.createdAt,
      contextSummary: result.contextSummary,
    );
  }

  Future<void> clearHistory() async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Sign in is required to clear synced history.');
    }

    await _clearLocalFallbackMessages(uid);

    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.users)
          .doc(uid)
          .collection(AppConstants.aiChatMessages)
          .get();
      if (snapshot.docs.isEmpty) {
        return;
      }
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e, stackTrace) {
      if (_isRecoverableFirestoreSyncError(e)) {
        Logger.warn(
          'AI history clear skipped because Firestore denied access: ${e.message ?? e.code}',
        );
        return;
      }
      Logger.error('AI history clear failed', e, stackTrace);
      throw StateError('Failed to clear chat history.');
    } catch (e, stackTrace) {
      Logger.error('AI history clear failed', e, stackTrace);
      throw StateError('Failed to clear chat history.');
    }
  }

  Future<List<AIChatMessage>> _loadRecentHistorySafe(String uid) async {
    try {
      return await _loadRecentHistory(uid);
    } on FirebaseException catch (e, stackTrace) {
      if (_isRecoverableFirestoreSyncError(e)) {
        Logger.warn(
          'AI history sync unavailable, continuing without Firestore history: '
          '${e.message ?? e.code}',
        );
        return _loadLocalFallbackMessages(uid);
      }
      Logger.error('Failed to load AI history', e, stackTrace);
      rethrow;
    }
  }

  Future<List<AIChatMessage>> _loadRecentHistory(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      return _loadLocalFallbackMessages(uid);
    }

    final snapshot = await firestore
        .collection(AppConstants.users)
        .doc(uid)
        .collection(AppConstants.aiChatMessages)
        .orderBy('createdAt', descending: true)
        .limit(_historyLimit)
        .get();

    return snapshot.docs
        .map(AIChatMessage.fromFirestore)
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<void> _writeMessageSafe(
    String uid,
    AIChatMessage message, {
    required AIEntryContext entryContext,
    required String requestId,
  }) async {
    await _writeMessageLocalSafe(
      uid,
      message,
      entryContext: entryContext,
      requestId: requestId,
    );
    try {
      await _writeMessage(
        uid,
        message,
        entryContext: entryContext,
        requestId: requestId,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (_isRecoverableFirestoreSyncError(e)) {
        Logger.warn(
          'AI chat sync unavailable, keeping message in local storage only: '
          '${e.message ?? e.code}',
        );
        return;
      }
      Logger.error('Failed to persist AI message', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _writeMessage(
    String uid,
    AIChatMessage message, {
    required AIEntryContext entryContext,
    required String requestId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'ai_chatbot_service',
        code: 'unavailable',
        message: 'Firestore is unavailable.',
      );
    }

    await firestore
        .collection(AppConstants.users)
        .doc(uid)
        .collection(AppConstants.aiChatMessages)
        .doc(message.id)
        .set({
          'role': message.role,
          'text': message.text,
          'requestId': requestId,
          'contextType': entryContext.type.name,
          'pagodaId': entryContext.pagodaId,
          'tripId': entryContext.tripId,
          'createdAt': Timestamp.fromDate(message.createdAt),
        });
  }

  List<AIChatMessage> _normalizeHistory(List<AIChatMessage> history) {
    return history
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false)
        .takeLast(_historyLimit);
  }

  Future<List<AIChatMessage>> _loadLocalFallbackMessages(String uid) async {
    try {
      final rows = await _localDb.getLocalAiChatMessages(
        ownerUserId: uid,
        limit: _historyLimit * 2,
      );
      final messages =
          rows
              .map((row) => AIChatMessage.fromLocalJson(row))
              .where((message) => message.text.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages.takeLast(_historyLimit);
    } on UnsupportedError {
      return const [];
    } catch (e, stackTrace) {
      Logger.error('Failed to load local AI chat history', e, stackTrace);
      return const [];
    }
  }

  Future<void> _writeMessageLocalSafe(
    String uid,
    AIChatMessage message, {
    required AIEntryContext entryContext,
    required String requestId,
  }) async {
    try {
      await _localDb.insertLocalAiChatMessage(
        ownerUserId: uid,
        id: message.id,
        role: message.role,
        text: message.text,
        createdAt: message.createdAt,
        requestId: requestId,
        contextType: entryContext.type.name,
        pagodaId: entryContext.pagodaId,
        tripId: entryContext.tripId,
      );
    } on UnsupportedError {
      return;
    } catch (e, stackTrace) {
      Logger.error('Failed to persist local AI chat history', e, stackTrace);
    }
  }

  Future<void> _clearLocalFallbackMessages(String uid) async {
    try {
      await _localDb.clearLocalAiChatMessages(ownerUserId: uid);
    } on UnsupportedError {
      return;
    } catch (e, stackTrace) {
      Logger.error('Failed to clear local AI chat history', e, stackTrace);
    }
  }

  bool _isRecoverableFirestoreSyncError(FirebaseException exception) {
    if (exception.code == 'permission-denied' ||
        exception.code == 'unavailable' ||
        exception.code == 'failed-precondition' ||
        exception.code == 'not-found') {
      return true;
    }
    final message = (exception.message ?? '').toLowerCase();
    return message.contains('database') && message.contains('does not exist');
  }

  static bool containsMyanmarScript(String text) {
    return _myanmarScriptPattern.hasMatch(text);
  }

  static String sanitizeAssistantReply(String reply) {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (containsMyanmarScript(trimmed)) {
      return englishOnlyFallbackReply;
    }
    return trimmed;
  }

  String _sanitizeAssistantReply(String reply) {
    final trimmed = reply.trim();
    final sanitized = sanitizeAssistantReply(reply);
    if (sanitized == englishOnlyFallbackReply &&
        trimmed != englishOnlyFallbackReply) {
      Logger.warn(
        'AI reply contained Myanmar script and was replaced with an English-only fallback.',
      );
    }
    return sanitized;
  }

  List<AIPagodaContext> _selectRelevantPagodas({
    required String prompt,
    required List<AIPagodaContext> pagodas,
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
  }) {
    if (pagodas.isEmpty) {
      return const [];
    }

    final tripPagodaIds =
        tripContext?.stops.map((stop) => stop.pagodaId).toSet() ?? <String>{};
    final normalizedPrompt = _normalizeSearchText(prompt);
    final promptTokens = _keywordTokens(prompt);
    final scored =
        pagodas
            .map((pagoda) {
              var score = 0;
              final normalizedName = _normalizeSearchText(pagoda.name);
              final normalizedId = _normalizeSearchText(pagoda.id);
              if ((entryContext.pagodaId ?? '').isNotEmpty &&
                  pagoda.id == entryContext.pagodaId) {
                score += 16;
              }
              if (tripPagodaIds.contains(pagoda.id)) {
                score += 10;
              }
              if (normalizedPrompt.contains(normalizedName) &&
                  normalizedName.isNotEmpty) {
                score += 12;
              }
              if (normalizedPrompt.contains(normalizedId) &&
                  normalizedId.isNotEmpty) {
                score += 12;
              }
              for (final token in _keywordTokens(
                '${pagoda.id} ${pagoda.name}',
              )) {
                if (token.length >= 4 && promptTokens.contains(token)) {
                  score += 4;
                }
              }
              return (pagoda: pagoda, score: score);
            })
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    final selected = scored
        .where((item) => item.score > 0)
        .take(8)
        .map((item) => item.pagoda)
        .toList(growable: false);
    if (selected.isNotEmpty) {
      return selected;
    }
    return pagodas.take(4).toList(growable: false);
  }

  List<AICommunityPostContext> _selectRelevantCommunityPosts({
    required String prompt,
    required List<AICommunityPostContext> communityPosts,
    required List<AIPagodaContext> relevantPagodas,
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
  }) {
    if (communityPosts.isEmpty) {
      return const [];
    }

    final promptText = _normalizeSearchText(prompt);
    final promptTokens = _keywordTokens(prompt);
    final targetTerms = <String>{
      ...relevantPagodas.map((pagoda) => _normalizeSearchText(pagoda.id)),
      ...relevantPagodas.map((pagoda) => _normalizeSearchText(pagoda.name)),
      if ((entryContext.pagodaId ?? '').isNotEmpty)
        _normalizeSearchText(entryContext.pagodaId!),
      if (tripContext != null)
        ...tripContext.stops.map((stop) => _normalizeSearchText(stop.pagodaId)),
    }.where((term) => term.isNotEmpty).toSet();

    final scored =
        communityPosts
            .map((post) {
              final searchable = _normalizeSearchText(
                [
                  post.title,
                  post.body,
                  post.authorName,
                  post.tags.join(' '),
                ].join(' '),
              );
              var score = 0;
              if (promptText.isNotEmpty && searchable.contains(promptText)) {
                score += 16;
              }
              for (final term in targetTerms) {
                if (term.length >= 4 && searchable.contains(term)) {
                  score += 8;
                }
              }
              for (final token in promptTokens) {
                if (token.length >= 4 && searchable.contains(token)) {
                  score += 2;
                }
              }
              for (final tag in post.tags) {
                final normalizedTag = _normalizeSearchText(tag);
                if (normalizedTag.isNotEmpty &&
                    promptTokens.contains(normalizedTag)) {
                  score += 4;
                }
              }
              return (post: post, score: score);
            })
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            final votesCompare = b.post.upvoteCount.compareTo(
              a.post.upvoteCount,
            );
            if (votesCompare != 0) {
              return votesCompare;
            }
            return b.post.createdAt.compareTo(a.post.createdAt);
          });

    final selected = scored
        .where((item) => item.score > 0)
        .take(6)
        .map((item) => item.post)
        .toList(growable: false);
    if (selected.isNotEmpty) {
      return selected;
    }
    return const [];
  }

  String _normalizeSearchText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _keywordTokens(String text) {
    return _normalizeSearchText(text)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet();
  }
}

extension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) {
      return List<T>.from(this, growable: false);
    }
    return sublist(length - count, length);
  }
}
