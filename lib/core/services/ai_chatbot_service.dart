import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/road_report_model.dart';
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

class AIRoadReportContext {
  final String id;
  final String pagodaId;
  final String pagodaName;
  final String category;
  final String severity;
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AIRoadReportContext({
    required this.id,
    required this.pagodaId,
    required this.pagodaName,
    required this.category,
    required this.severity,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
  });

  factory AIRoadReportContext.fromRoadReport(RoadReport report) {
    return AIRoadReportContext(
      id: report.id,
      pagodaId: report.pagodaId,
      pagodaName: report.pagodaName,
      category: report.category,
      severity: report.severity,
      note: report.note,
      createdAt: report.createdAt,
      expiresAt: report.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pagodaId': pagodaId,
      'pagodaName': pagodaName,
      'category': category,
      'severity': severity,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
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
  static const String _directNvidiaApiKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
  );
  static const String _directNvidiaModel = String.fromEnvironment(
    'NVIDIA_MODEL',
    defaultValue: 'meta/llama-3.1-8b-instruct',
  );
  static const String _directNvidiaEndpoint =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const int _historyLimit = 12;

  AIChatbotService({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    http.Client? httpClient,
    DatabaseService? databaseService,
  }) : _firestore = firestore ?? FirestoreInstance.instance,
       _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _localDb = databaseService ?? DatabaseService();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  final http.Client _httpClient;
  final DatabaseService _localDb;

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isConfigured => _directNvidiaApiKey.trim().isNotEmpty;

  Stream<List<AIChatMessage>> messageStream() {
    final uid = currentUserId;
    if (uid == null) {
      return Stream.value(const []);
    }

    return _firestore
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
    String? model,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Sign in is required to use the AI assistant.');
    }
    final directNvidiaKey = _directNvidiaApiKey.trim();
    if (directNvidiaKey.isEmpty) {
      throw StateError(
        'NVIDIA_API_KEY is not configured. Launch Flutter with '
        '--dart-define=NVIDIA_API_KEY=your_nvidia_key',
      );
    }

    try {
      final history = historyOverride != null
          ? _normalizeHistory(historyOverride)
          : await _loadRecentHistorySafe(uid);
      final relevantPagodas = _selectRelevantPagodas(
        prompt: prompt,
        pagodas: pagodaContext,
        entryContext: entryContext,
        tripContext: tripContext,
      );
      final roadReports = await _loadRelevantRoadReportsSafe(
        entryContext: entryContext,
        tripContext: tripContext,
        promptPagodaIds: relevantPagodas.map((pagoda) => pagoda.id).toSet(),
      );
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

      final result = await _requestDirectNvidiaReply(
        prompt: prompt,
        directNvidiaKey: directNvidiaKey,
        history: history,
        pagodaContext: pagodaContext,
        communityContext: communityContext,
        entryContext: entryContext,
        tripContext: tripContext,
        roadReports: roadReports,
        model: model,
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
      Logger.error('Unexpected AI HTTP request failure', e, stackTrace);
      rethrow;
    }
  }

  Future<AIReplyResult> _requestDirectNvidiaReply({
    required String prompt,
    required String directNvidiaKey,
    required List<AIChatMessage> history,
    required List<AIPagodaContext> pagodaContext,
    required List<AICommunityPostContext> communityContext,
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
    required List<AIRoadReportContext> roadReports,
    String? model,
  }) async {
    final relevantPagodas = _selectRelevantPagodas(
      prompt: prompt,
      pagodas: pagodaContext,
      entryContext: entryContext,
      tripContext: tripContext,
    );
    final relevantRoadReports = _selectRelevantRoadReports(
      roadReports: roadReports,
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
    final response = await _httpClient
        .post(
          Uri.parse(_directNvidiaEndpoint),
          headers: {
            'Authorization': 'Bearer $directNvidiaKey',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': (model ?? '').trim().isNotEmpty
                ? model!.trim()
                : _directNvidiaModel,
            'temperature': 0.2,
            'top_p': 0.9,
            'max_tokens': 700,
            'messages': [
              {
                'role': 'system',
                'content': _buildDirectSystemPrompt(
                  entryContext: entryContext,
                  pagodas: relevantPagodas,
                  tripContext: tripContext,
                  roadReports: relevantRoadReports,
                  communityPosts: relevantCommunityPosts,
                ),
              },
              ...history.map(
                (message) => {
                  'role': message.role == AIChatMessage.roleAssistant
                      ? AIChatMessage.roleAssistant
                      : AIChatMessage.roleUser,
                  'content': message.text,
                },
              ),
              {'role': AIChatMessage.roleUser, 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    final data = _decodeResponseBody(
      response.body,
      statusCode: response.statusCode,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _extractApiErrorMessage(
        data,
        statusCode: response.statusCode,
      );
      Logger.warn(
        'NVIDIA API request failed '
        '(status ${response.statusCode}): $errorMessage',
      );
      throw StateError(errorMessage);
    }

    final replyText = _extractReplyText(data);
    if (replyText.isEmpty) {
      throw StateError('Direct NVIDIA request returned no reply.');
    }

    return AIReplyResult(
      reply: replyText,
      createdAt: DateTime.now(),
      contextSummary: {
        'pagodaCount': relevantPagodas.length,
        'tripCount': tripContext == null ? 0 : 1,
        'roadReportCount': relevantRoadReports.length,
        'communityPostCount': relevantCommunityPosts.length,
      },
    );
  }

  Future<void> clearHistory() async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Sign in is required to clear synced history.');
    }

    await _clearLocalFallbackMessages(uid);

    try {
      final snapshot = await _firestore
          .collection(AppConstants.users)
          .doc(uid)
          .collection(AppConstants.aiChatMessages)
          .get();
      if (snapshot.docs.isEmpty) {
        return;
      }
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e, stackTrace) {
      if (_isPermissionDenied(e)) {
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
      if (_isPermissionDenied(e)) {
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
    final snapshot = await _firestore
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

  Future<List<AIRoadReportContext>> _loadRelevantRoadReportsSafe({
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
    Set<String> promptPagodaIds = const <String>{},
  }) async {
    try {
      return await _loadRelevantRoadReports(
        entryContext: entryContext,
        tripContext: tripContext,
        promptPagodaIds: promptPagodaIds,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (_isPermissionDenied(e)) {
        Logger.warn(
          'Road report sync unavailable, continuing without Firestore road reports: '
          '${e.message ?? e.code}',
        );
        return const [];
      }
      Logger.error('Failed to load road reports', e, stackTrace);
      rethrow;
    }
  }

  Future<List<AIRoadReportContext>> _loadRelevantRoadReports({
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
    Set<String> promptPagodaIds = const <String>{},
  }) async {
    final pagodaIds = <String>{
      if ((entryContext.pagodaId ?? '').isNotEmpty) entryContext.pagodaId!,
      if (tripContext != null)
        ...tripContext.stops.map((stop) => stop.pagodaId),
      ...promptPagodaIds,
    };
    if (pagodaIds.isEmpty) {
      return const [];
    }

    final reports = <AIRoadReportContext>[];
    for (final pagodaId in pagodaIds) {
      final snapshot = await _firestore
          .collection(AppConstants.roadReports)
          .where('pagodaId', isEqualTo: pagodaId)
          .limit(12)
          .get();
      for (final doc in snapshot.docs) {
        final report = RoadReport.fromJson(doc.data(), id: doc.id);
        if (!report.isActive) {
          continue;
        }
        reports.add(AIRoadReportContext.fromRoadReport(report));
      }
    }

    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports.take(12).toList(growable: false);
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
      if (_isPermissionDenied(e)) {
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
    await _firestore
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

  bool _isPermissionDenied(FirebaseException exception) {
    return exception.code == 'permission-denied';
  }

  Map<String, dynamic> _decodeResponseBody(String body, {int? statusCode}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw const FormatException('AI backend returned an invalid response.');
    } on FormatException {
      final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      return {
        'error': compact.isEmpty
            ? 'AI service returned an invalid response.'
            : compact,
      };
    }
  }

  String _extractApiErrorMessage(Map<String, dynamic> data, {int? statusCode}) {
    final title = _readApiText(data['title']);
    final detail = _readApiText(data['detail']);
    final combinedTitleAndDetail = _joinDistinctParts([title, detail]);
    final message = _firstNonEmptyText([
      combinedTitleAndDetail,
      _readApiText(data['message']),
      _readApiText(data['error']),
      _readApiText(data['errors']),
    ]);
    if (message != null) {
      return message;
    }

    switch (statusCode) {
      case 400:
        return 'NVIDIA API rejected the request.';
      case 401:
        return 'NVIDIA API authentication failed. Check the API key.';
      case 403:
        return 'NVIDIA API access was denied for this key or model.';
      case 404:
        return 'NVIDIA API endpoint or model was not found.';
      case 429:
        return 'NVIDIA API rate limit exceeded. Try again later.';
      default:
        if (statusCode != null && statusCode >= 500) {
          return 'NVIDIA API is temporarily unavailable. Try again later.';
        }
        if (statusCode != null) {
          return 'Direct NVIDIA request failed (HTTP $statusCode).';
        }
        return 'Direct NVIDIA request failed.';
    }
  }

  String _extractReplyText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List) {
      for (final choice in choices) {
        if (choice is! Map) {
          continue;
        }
        final choiceMap = choice.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final message = choiceMap['message'];
        if (message is Map) {
          final reply = _readApiText(message['content']);
          if (reply != null) {
            return reply;
          }
        }
        final reply = _readApiText(choiceMap['text']);
        if (reply != null) {
          return reply;
        }
      }
    }

    return _readApiText(data['output_text']) ?? '';
  }

  String? _readApiText(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is List) {
      final parts = value
          .map(_readApiText)
          .whereType<String>()
          .where((part) => part.trim().isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty) {
        return null;
      }
      return _joinDistinctParts(parts);
    }
    if (value is Map) {
      final map = value.map((key, val) => MapEntry(key.toString(), val));
      return _firstNonEmptyText([
        _joinDistinctParts([
          _readApiText(map['title']),
          _readApiText(map['detail']),
        ]),
        _readApiText(map['message']),
        _readApiText(map['text']),
        _readApiText(map['content']),
        _readApiText(map['error']),
        _readApiText(map['errors']),
        _readApiText(map['code']),
      ]);
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _firstNonEmptyText(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _joinDistinctParts(Iterable<String?> parts) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final part in parts) {
      final trimmed = (part ?? '').trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final lower = trimmed.toLowerCase();
      if (seen.add(lower)) {
        normalized.add(trimmed);
      }
    }

    return normalized.join(': ');
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

  List<AIRoadReportContext> _selectRelevantRoadReports({
    required List<AIRoadReportContext> roadReports,
    required AIEntryContext entryContext,
    required AITripContext? tripContext,
  }) {
    final targetPagodaIds = <String>{
      if ((entryContext.pagodaId ?? '').isNotEmpty) entryContext.pagodaId!,
      if (tripContext != null)
        ...tripContext.stops.map((stop) => stop.pagodaId),
    };

    final filtered =
        roadReports
            .where((report) {
              if (report.expiresAt.isBefore(DateTime.now())) {
                return false;
              }
              if (targetPagodaIds.isEmpty) {
                return true;
              }
              return targetPagodaIds.contains(report.pagodaId);
            })
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(12).toList(growable: false);
  }

  String _buildDirectSystemPrompt({
    required AIEntryContext entryContext,
    required List<AIPagodaContext> pagodas,
    required AITripContext? tripContext,
    required List<AIRoadReportContext> roadReports,
    required List<AICommunityPostContext> communityPosts,
  }) {
    final pagodaBlock = pagodas.isEmpty
        ? '- No pagoda context supplied.'
        : pagodas
              .map((pagoda) {
                final lines = <String>[
                  '- ${pagoda.name} (${pagoda.category}, id: ${pagoda.id})',
                  '  Summary: ${pagoda.summary}',
                ];
                if ((pagoda.bestTime ?? '').trim().isNotEmpty) {
                  lines.add('  Best time: ${pagoda.bestTime!.trim()}');
                }
                if ((pagoda.openingHours ?? '').trim().isNotEmpty) {
                  lines.add('  Opening hours: ${pagoda.openingHours!.trim()}');
                }
                if ((pagoda.location ?? '').trim().isNotEmpty) {
                  lines.add('  Location: ${pagoda.location!.trim()}');
                }
                return lines.join('\n');
              })
              .join('\n');

    final tripBlock = tripContext == null
        ? '- No trip context supplied.'
        : '- ${tripContext.name}: '
              '${tripContext.stops.map((stop) => stop.pagodaName).join(' -> ')}';

    final roadReportBlock = roadReports.isEmpty
        ? '- No active road reports supplied.'
        : roadReports
              .map(
                (report) =>
                    '- ${report.pagodaName}: ${report.category} '
                    '(${report.severity}) - ${report.note}',
              )
              .join('\n');

    final communityBlock = communityPosts.isEmpty
        ? '- No relevant community posts supplied.'
        : communityPosts
              .map(
                (post) =>
                    '- ${post.title} (${post.type}, by ${post.authorName}, '
                    '${post.upvoteCount} upvotes, ${post.commentCount} comments): '
                    '${post.body}${post.tags.isEmpty ? '' : ' [tags: ${post.tags.join(', ')}]'}',
              )
              .join('\n');

    return [
      "You are Baganetic's in-app travel assistant for Bagan pagodas.",
      'Stay inside the Bagan travel domain and answer concisely.',
      'Use the provided pagoda, trip, road report, and community context when relevant.',
      'Road reports are informational only. Warn users, but do not claim automatic rerouting.',
      'Community posts are user-submitted and unverified. Present them as community reports, not confirmed facts.',
      'If facts are missing, say so clearly rather than inventing details.',
      'Entry context type: ${entryContext.type.name}',
      '',
      'Pagoda context:',
      pagodaBlock,
      '',
      'Trip context:',
      tripBlock,
      '',
      'Road report context:',
      roadReportBlock,
      '',
      'Community feed context:',
      communityBlock,
    ].join('\n');
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
