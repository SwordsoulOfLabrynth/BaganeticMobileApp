import '../models/chat_group.dart';
import '../models/chat_message.dart';

class ChatPage<T, C> {
  const ChatPage({required this.items, required this.nextCursor});

  final List<T> items;
  final C? nextCursor;

  bool get hasMore => nextCursor != null;
}

class ChatGroupsCursor {
  const ChatGroupsCursor({required this.lastMessageAt, required this.groupId});

  final DateTime lastMessageAt;
  final String groupId;
}

class ChatMessagesCursor {
  const ChatMessagesCursor({required this.sentAt, required this.messageId});

  final DateTime sentAt;
  final String messageId;
}

abstract class ChatRepository {
  static final DateTime minCursorDate = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  String? get currentUserId;

  Stream<List<ChatGroup>> watchGroups({int limit = 20});

  Future<ChatPage<ChatGroup, ChatGroupsCursor>> fetchGroupsPage({
    ChatGroupsCursor? cursor,
    int limit = 20,
  });

  Stream<Set<String>> watchMyGroupIds();

  Stream<Map<String, int>> watchMemberCountsForGroups(List<String> groupIds);

  Stream<List<ChatMessage>> watchMessages({
    required String groupId,
    int limit = 50,
  });

  Future<ChatPage<ChatMessage, ChatMessagesCursor>> fetchMessagesPage({
    required String groupId,
    ChatMessagesCursor? cursor,
    int limit = 50,
  });

  Future<String> createGroup(String name);

  Future<void> joinGroup(String groupId);

  Future<void> sendMessage(String groupId, String text);
}
