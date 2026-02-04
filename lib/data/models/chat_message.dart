import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? sentAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      return ChatMessage(
        id: snapshot.id,
        groupId: '',
        senderId: '',
        senderName: 'Unknown',
        text: '',
        sentAt: null,
      );
    }

    return ChatMessage(
      id: snapshot.id,
      groupId: _toStringValue(data['groupId']),
      senderId: _toStringValue(data['senderId']),
      senderName: _toStringValue(data['senderName'], fallback: 'Unknown'),
      text: _toStringValue(data['text']),
      sentAt: _toDateTime(data['sentAt']) ?? _toDateTime(data['clientSentAt']),
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
