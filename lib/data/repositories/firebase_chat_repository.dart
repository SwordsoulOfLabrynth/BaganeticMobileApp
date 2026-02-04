import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;

import '../../core/constants/app_constants.dart';
import '../../core/errors/chat_errors.dart';
import '../../core/services/firestore_instance.dart';
import '../../core/services/logger.dart';
import '../models/chat_group.dart';
import '../models/chat_message.dart';
import 'chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirestoreInstance.instance,
       _auth = auth ?? firebase_auth.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;

  static const int _whereInLimit = 30;

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  String? get currentUserId {
    if (!_isFirebaseAvailable) {
      return null;
    }
    try {
      return _auth.currentUser?.uid;
    } catch (e) {
      Logger.error('FirebaseChatRepository: Error getting current user', e);
      return null;
    }
  }

  @override
  Stream<List<ChatGroup>> watchGroups({int limit = 20}) {
    if (!_isFirebaseAvailable) {
      return Stream.value(<ChatGroup>[]);
    }
    try {
      return _groupsBaseQuery(limit: limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map<DocumentSnapshot<Map<String, dynamic>>>((doc) => doc)
                .map(ChatGroup.fromSnapshot)
                .toList(),
          )
          .handleError((error, stackTrace) {
            if (_isMissingFirestoreDatabase(error)) {
              Logger.error(
                'FirebaseChatRepository: Firestore database not configured',
                error,
                stackTrace,
              );
            } else {
              Logger.error(
                'FirebaseChatRepository: watchGroups error',
                error,
                stackTrace,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          });
    } catch (e, st) {
      Logger.error('FirebaseChatRepository: watchGroups failed', e, st);
      return Stream.value(<ChatGroup>[]);
    }
  }

  @override
  Future<ChatPage<ChatGroup, ChatGroupsCursor>> fetchGroupsPage({
    ChatGroupsCursor? cursor,
    int limit = 20,
  }) async {
    if (!_isFirebaseAvailable) {
      throw NetworkError(
        'Firebase is not available. Please check your connection and try again.',
        code: 'firebase-not-initialized',
      );
    }
    try {
      final snapshot = await _groupsBaseQuery(limit: limit, cursor: cursor)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw FirebaseException(
                plugin: 'firebase_chat_repository',
                code: 'deadline-exceeded',
                message:
                    'Firestore operation timed out. The database may not be configured.',
              );
            },
          );
      final groups = snapshot.docs
          .map<DocumentSnapshot<Map<String, dynamic>>>((doc) => doc)
          .map(ChatGroup.fromSnapshot)
          .toList();

      return ChatPage(
        items: groups,
        nextCursor: _nextGroupCursor(snapshot.docs, limit),
      );
    } catch (error, stackTrace) {
      Logger.error(
        'FirebaseChatRepository: fetchGroupsPage failed',
        error,
        stackTrace,
      );
      throw _mapError(error);
    }
  }

  Query<Map<String, dynamic>> _groupsBaseQuery({
    required int limit,
    ChatGroupsCursor? cursor,
  }) {
    var query = _firestore
        .collection(AppConstants.chatGroups)
        .orderBy('lastMessageAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.lastMessageAt),
        cursor.groupId,
      ]);
    }

    return query;
  }

  ChatGroupsCursor? _nextGroupCursor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    if (docs.length < pageSize) {
      return null;
    }
    final lastDoc = docs.last;
    final timestamp =
        _toDateTime(lastDoc.data()['lastMessageAt']) ??
        ChatRepository.minCursorDate;
    return ChatGroupsCursor(lastMessageAt: timestamp, groupId: lastDoc.id);
  }

  @override
  Stream<Set<String>> watchMyGroupIds() {
    if (!_isFirebaseAvailable) {
      return Stream.value(<String>{});
    }
    final uid = currentUserId;
    if (uid == null) {
      return Stream.value(<String>{});
    }
    try {
      return _firestore
          .collection(AppConstants.chatGroupMembers)
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => doc.data()['groupId'] as String?)
                .whereType<String>()
                .where((groupId) => groupId.isNotEmpty)
                .toSet(),
          )
          .handleError((error, stackTrace) {
            if (_isMissingFirestoreDatabase(error)) {
              Logger.error(
                'FirebaseChatRepository: Firestore database not configured',
                error,
                stackTrace,
              );
            } else {
              Logger.error(
                'FirebaseChatRepository: watchMyGroupIds error',
                error,
                stackTrace,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          });
    } catch (e, st) {
      Logger.error('FirebaseChatRepository: watchMyGroupIds failed', e, st);
      return Stream.value(<String>{});
    }
  }

  @override
  Stream<Map<String, int>> watchMemberCountsForGroups(List<String> groupIds) {
    if (!_isFirebaseAvailable) {
      return Stream.value(<String, int>{});
    }
    final uniqueGroupIds =
        groupIds.toSet().where((id) => id.isNotEmpty).toList()..sort();
    if (uniqueGroupIds.isEmpty) {
      return Stream.value(<String, int>{});
    }

    try {
      final streams = _chunk(uniqueGroupIds, _whereInLimit)
          .map(
            (chunk) => _firestore
                .collection(AppConstants.chatGroupMembers)
                .where('groupId', whereIn: chunk)
                .snapshots()
                .map(_countMembersByGroup)
                .handleError((error, stackTrace) {
                  if (_isMissingFirestoreDatabase(error)) {
                    Logger.error(
                      'FirebaseChatRepository: Firestore database not configured',
                      error,
                      stackTrace,
                    );
                  } else {
                    Logger.error(
                      'FirebaseChatRepository: watchMemberCountsForGroups error',
                      error,
                      stackTrace,
                    );
                  }
                  Error.throwWithStackTrace(error, stackTrace);
                }),
          )
          .toList();

      return _mergeCountStreams(streams);
    } catch (e, st) {
      Logger.error(
        'FirebaseChatRepository: watchMemberCountsForGroups failed',
        e,
        st,
      );
      return Stream.value(<String, int>{});
    }
  }

  Map<String, int> _countMembersByGroup(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final groupId = doc.data()['groupId'] as String?;
      if (groupId == null || groupId.isEmpty) {
        continue;
      }
      counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Stream<Map<String, int>> _mergeCountStreams(
    List<Stream<Map<String, int>>> streams,
  ) {
    if (streams.isEmpty) {
      return Stream.value(<String, int>{});
    }

    final controller = StreamController<Map<String, int>>();
    final latestChunkCounts = <int, Map<String, int>>{};
    final subscriptions = <StreamSubscription<Map<String, int>>>[];

    void emitMergedCounts() {
      final merged = <String, int>{};
      for (final chunkCounts in latestChunkCounts.values) {
        chunkCounts.forEach((groupId, memberCount) {
          merged.update(
            groupId,
            (value) => value + memberCount,
            ifAbsent: () => memberCount,
          );
        });
      }
      controller.add(merged);
    }

    for (var i = 0; i < streams.length; i++) {
      final sub = streams[i].listen(
        (counts) {
          latestChunkCounts[i] = counts;
          emitMergedCounts();
        },
        onError: (error, stackTrace) => controller.addError(error, stackTrace),
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      await Future.wait(subscriptions.map((sub) => sub.cancel()));
    };

    return controller.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String groupId,
    int limit = 50,
  }) {
    if (!_isFirebaseAvailable) {
      return Stream.value(<ChatMessage>[]);
    }
    try {
      return _messagesBaseQuery(groupId: groupId, limit: limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map<DocumentSnapshot<Map<String, dynamic>>>((doc) => doc)
                .map(ChatMessage.fromSnapshot)
                .toList(),
          )
          .handleError((error, stackTrace) {
            if (_isMissingFirestoreDatabase(error)) {
              Logger.error(
                'FirebaseChatRepository: Firestore database not configured',
                error,
                stackTrace,
              );
            } else {
              Logger.error(
                'FirebaseChatRepository: watchMessages error',
                error,
                stackTrace,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          });
    } catch (e, st) {
      Logger.error('FirebaseChatRepository: watchMessages failed', e, st);
      return Stream.value(<ChatMessage>[]);
    }
  }

  @override
  Future<ChatPage<ChatMessage, ChatMessagesCursor>> fetchMessagesPage({
    required String groupId,
    ChatMessagesCursor? cursor,
    int limit = 50,
  }) async {
    if (!_isFirebaseAvailable) {
      throw NetworkError(
        'Firebase is not available. Please check your connection and try again.',
        code: 'firebase-not-initialized',
      );
    }
    try {
      final snapshot =
          await _messagesBaseQuery(
            groupId: groupId,
            limit: limit,
            cursor: cursor,
          ).get().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw FirebaseException(
                plugin: 'firebase_chat_repository',
                code: 'deadline-exceeded',
                message:
                    'Firestore operation timed out. The database may not be configured.',
              );
            },
          );
      final messages = snapshot.docs
          .map<DocumentSnapshot<Map<String, dynamic>>>((doc) => doc)
          .map(ChatMessage.fromSnapshot)
          .toList();

      return ChatPage(
        items: messages,
        nextCursor: _nextMessageCursor(snapshot.docs, limit),
      );
    } catch (error, stackTrace) {
      Logger.error(
        'FirebaseChatRepository: fetchMessagesPage failed',
        error,
        stackTrace,
      );
      throw _mapError(error);
    }
  }

  Query<Map<String, dynamic>> _messagesBaseQuery({
    required String groupId,
    required int limit,
    ChatMessagesCursor? cursor,
  }) {
    var query = _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId)
        .collection(AppConstants.chatMessages)
        .orderBy('sentAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.sentAt),
        cursor.messageId,
      ]);
    }

    return query;
  }

  ChatMessagesCursor? _nextMessageCursor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    if (docs.length < pageSize) {
      return null;
    }
    final lastDoc = docs.last;
    final timestamp =
        _toDateTime(lastDoc.data()['sentAt']) ?? ChatRepository.minCursorDate;
    return ChatMessagesCursor(sentAt: timestamp, messageId: lastDoc.id);
  }

  @override
  Future<String> createGroup(String name) async {
    if (!_isFirebaseAvailable) {
      throw NetworkError(
        'Firebase is not available. Please check your connection and try again.',
        code: 'firebase-not-initialized',
      );
    }
    final user = _requireUser();
    final displayName = user.displayName ?? user.email ?? 'User';
    final trimmedName = name.trim();

    if (trimmedName.length < 3) {
      throw const ValidationError('Group name must be at least 3 characters.');
    }

    final groupRef = _firestore.collection(AppConstants.chatGroups).doc();
    final memberRef = _firestore
        .collection(AppConstants.chatGroupMembers)
        .doc(_memberDocId(groupRef.id, user.uid));

    try {
      await _withNetworkRetry(() async {
        final batch = _firestore.batch();
        batch.set(groupRef, {
          'name': trimmedName,
          'createdBy': user.uid,
          'createdByName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'memberCount': 1,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
        batch.set(memberRef, {
          'groupId': groupRef.id,
          'userId': user.uid,
          'role': 'admin',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      });
    } catch (error, stackTrace) {
      Logger.error(
        'FirebaseChatRepository: createGroup failed',
        error,
        stackTrace,
      );
      throw _mapError(error);
    }

    return groupRef.id;
  }

  @override
  Future<void> joinGroup(String groupId) async {
    if (!_isFirebaseAvailable) {
      throw NetworkError(
        'Firebase is not available. Please check your connection and try again.',
        code: 'firebase-not-initialized',
      );
    }
    final user = _requireUser();
    final groupRef = _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId);
    final memberRef = _firestore
        .collection(AppConstants.chatGroupMembers)
        .doc(_memberDocId(groupId, user.uid));

    try {
      await _withNetworkRetry(() async {
        await _firestore.runTransaction((transaction) async {
          final memberSnapshot = await transaction.get(memberRef);
          if (memberSnapshot.exists) {
            return;
          }

          transaction.set(memberRef, {
            'groupId': groupId,
            'userId': user.uid,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(groupRef, {
            'memberCount': FieldValue.increment(1),
          });
        });
      });
    } catch (error, stackTrace) {
      Logger.error(
        'FirebaseChatRepository: joinGroup failed',
        error,
        stackTrace,
      );
      throw _mapError(error);
    }
  }

  @override
  Future<void> sendMessage(String groupId, String text) async {
    if (!_isFirebaseAvailable) {
      throw NetworkError(
        'Firebase is not available. Please check your connection and try again.',
        code: 'firebase-not-initialized',
      );
    }
    final user = _requireUser();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ValidationError('Message text cannot be empty.');
    }

    // Check if user is a member of the group
    final memberRef = _firestore
        .collection(AppConstants.chatGroupMembers)
        .doc(_memberDocId(groupId, user.uid));
    final memberSnapshot = await memberRef.get();

    if (!memberSnapshot.exists) {
      throw const PermissionError(
        'You must be a member of this group to send messages.',
      );
    }

    final groupRef = _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId);
    final messageRef = groupRef.collection(AppConstants.chatMessages).doc();
    final displayName = user.displayName ?? user.email ?? 'User';
    final localSentAt = Timestamp.now();

    try {
      await _withNetworkRetry(() async {
        final batch = _firestore.batch();
        batch.set(messageRef, {
          'groupId': groupId,
          'senderId': user.uid,
          'senderName': displayName,
          'text': trimmed,
          // Keeps local ordering stable while serverTimestamp is still pending.
          'clientSentAt': localSentAt,
          'sentAt': FieldValue.serverTimestamp(),
        });
        batch.update(groupRef, {
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      });
    } catch (error, stackTrace) {
      Logger.error(
        'FirebaseChatRepository: sendMessage failed',
        error,
        stackTrace,
      );
      throw _mapError(error);
    }
  }

  firebase_auth.User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthError('You must be signed in to use chat.');
    }
    return user;
  }

  Future<void> _withNetworkRetry(Future<void> Function() action) async {
    const maxAttempts = 3;
    const timeoutDuration = Duration(seconds: 10);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await action().timeout(
          timeoutDuration,
          onTimeout: () {
            throw FirebaseException(
              plugin: 'firebase_chat_repository',
              code: 'deadline-exceeded',
              message:
                  'Firestore operation timed out. The database may not be configured.',
            );
          },
        );
        return;
      } catch (error) {
        final mappedError = _mapError(error);

        // Don't retry if it's a missing database error or validation error
        if (mappedError is ValidationError &&
            mappedError.code == 'firestore-database-not-configured') {
          rethrow;
        }

        if (mappedError is! NetworkError || attempt == maxAttempts) {
          rethrow;
        }

        final baseDelayMs = 200 * pow(2, attempt - 1).toInt();
        final jitterMs = Random().nextInt(120);
        await Future<void>.delayed(
          Duration(milliseconds: baseDelayMs + jitterMs),
        );
      }
    }
  }

  ChatError _mapError(Object error) {
    if (error is ChatError) {
      return error;
    }
    if (error is firebase_auth.FirebaseAuthException) {
      return AuthError(
        'Authentication failed.',
        code: error.code,
        cause: error,
      );
    }
    if (error is FirebaseException) {
      if (_isMissingFirestoreDatabase(error)) {
        return ValidationError(
          'Cloud Firestore is not configured for this Firebase project. '
          'Create a Firestore database in Firebase Console and try again.',
          code: 'firestore-database-not-configured',
          cause: error,
        );
      }
      switch (error.code) {
        case 'permission-denied':
          return PermissionError(
            'You do not have permission to perform this action.',
            code: error.code,
            cause: error,
          );
        case 'unauthenticated':
          return AuthError(
            'Please sign in again and retry.',
            code: error.code,
            cause: error,
          );
        case 'network-request-failed':
        case 'unavailable':
        case 'deadline-exceeded':
          return NetworkError(
            'Network connection issue.',
            code: error.code,
            cause: error,
          );
        case 'invalid-argument':
        case 'failed-precondition':
          return ValidationError(
            'Invalid chat request.',
            code: error.code,
            cause: error,
          );
        case 'not-found':
          return ValidationError(
            'Chat data was not found in Firestore.',
            code: error.code,
            cause: error,
          );
        default:
          return UnknownChatError(
            'Chat operation failed.',
            code: error.code,
            cause: error,
          );
      }
    }
    if (error is StateError) {
      return AuthError(error.message.toString(), cause: error);
    }
    return UnknownChatError('Unexpected chat error.', cause: error);
  }

  bool _isMissingFirestoreDatabase(Object error) {
    if (error is! FirebaseException) {
      return false;
    }
    final message = (error.message ?? '').toLowerCase();
    return error.code == 'not-found' &&
        message.contains('database') &&
        message.contains('does not exist');
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  List<List<String>> _chunk(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < values.length; i += size) {
      final end = min(i + size, values.length);
      chunks.add(values.sublist(i, end));
    }
    return chunks;
  }

  String _memberDocId(String groupId, String userId) {
    return '${groupId}_$userId';
  }
}
