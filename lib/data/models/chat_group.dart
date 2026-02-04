import 'package:cloud_firestore/cloud_firestore.dart';

class ChatGroup {
  final String id;
  final String name;
  final String createdBy;
  final DateTime? createdAt;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  ChatGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.memberCount,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory ChatGroup.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      return ChatGroup(
        id: snapshot.id,
        name: 'Unknown',
        createdBy: '',
        createdAt: null,
        memberCount: 0,
        lastMessage: null,
        lastMessageAt: null,
      );
    }

    return ChatGroup(
      id: snapshot.id,
      name: _toStringValue(data['name'], fallback: 'Unnamed'),
      createdBy: _toStringValue(data['createdBy']),
      createdAt: _toDateTime(data['createdAt']),
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      lastMessage: _toNullableStringValue(data['lastMessage']),
      lastMessageAt: _toDateTime(data['lastMessageAt']),
    );
  }

  static String _toStringValue(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return fallback;
  }

  static String? _toNullableStringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    return _toStringValue(value);
  }

  static DateTime? _toDateTime(dynamic value) {
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
}
