import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../constants/app_constants.dart';
import 'firestore_instance.dart';
import 'logger.dart';
import '../../data/models/chat_group.dart';
import '../../data/models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirestoreInstance.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static const int _groupPageSize = 50;
  static const int _messagePageSize = 100;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<ChatGroup>> streamGroups() {
    return _firestore
        .collection(AppConstants.chatGroups)
        .orderBy('lastMessageAt', descending: true)
        .limit(_groupPageSize)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ChatGroup.fromSnapshot(doc)).toList(),
        );
  }

  Stream<List<ChatMessage>> streamMessages(String groupId) {
    return _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId)
        .collection(AppConstants.chatMessages)
        .orderBy('sentAt', descending: true)
        .limit(_messagePageSize)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromSnapshot(doc))
              .toList(),
        );
  }

  Stream<Set<String>> streamMyGroupIds() {
    final uid = currentUserId;
    if (uid == null) {
      return Stream.value(<String>{});
    }
    return _firestore
        .collection(AppConstants.chatGroupMembers)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data()['groupId'] as String)
              .toSet(),
        );
  }

  Stream<Map<String, int>> streamGroupMemberCounts() {
    return _firestore.collection(AppConstants.chatGroupMembers).snapshots().map(
      (snapshot) {
        final counts = <String, int>{};
        for (final doc in snapshot.docs) {
          final groupId = doc.data()['groupId'] as String?;
          if (groupId == null || groupId.isEmpty) {
            continue;
          }
          counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
        }
        return counts;
      },
    );
  }

  Future<String> createGroup(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final groupRef = _firestore.collection(AppConstants.chatGroups).doc();
    final memberRef = _firestore
        .collection(AppConstants.chatGroupMembers)
        .doc(_memberDocId(groupRef.id, user.uid));
    final displayName = user.displayName ?? user.email ?? 'User';

    try {
      // Batched writes are queued offline, unlike transactions.
      final batch = _firestore.batch();
      batch.set(groupRef, {
        'name': name,
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
    } catch (e, st) {
      Logger.error('ChatService: failed to create group', e, st);
      rethrow;
    }

    return groupRef.id;
  }

  Future<void> joinGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final groupRef = _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId);
    final memberRef = _firestore
        .collection(AppConstants.chatGroupMembers)
        .doc(_memberDocId(groupId, user.uid));

    try {
      final memberSnap = await memberRef.get();
      if (memberSnap.exists) {
        return;
      }

      await memberRef.set({
        'groupId': groupId,
        'userId': user.uid,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Keep this best-effort because some rulesets may deny group doc updates.
      try {
        await groupRef.update({'memberCount': FieldValue.increment(1)});
      } catch (e, st) {
        Logger.warn(
          'ChatService: member joined, but failed to increment count',
        );
        Logger.error(
          'ChatService: failed to increment group memberCount',
          e,
          st,
        );
      }
    } catch (e, st) {
      Logger.error('ChatService: failed to join group', e, st);
      rethrow;
    }
  }

  Future<void> sendMessage(String groupId, String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final groupRef = _firestore
        .collection(AppConstants.chatGroups)
        .doc(groupId);
    final messageRef = groupRef.collection(AppConstants.chatMessages).doc();
    final displayName = user.displayName ?? user.email ?? 'User';
    final localSentAt = Timestamp.now();

    try {
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
    } catch (e, st) {
      Logger.error('ChatService: failed to send message', e, st);
      rethrow;
    }
  }

  String _memberDocId(String groupId, String userId) {
    return '${groupId}_$userId';
  }
}
