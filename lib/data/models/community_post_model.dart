import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  static const String statusActive = 'active';
  static const String typeTip = 'tip';
  static const String typeQuestion = 'question';

  final String id;
  final String authorUserId;
  final String authorName;
  final String type;
  final String title;
  final String body;
  final List<String> tags;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int upvoteCount;
  final int commentCount;
  final bool isUpvoted;

  const CommunityPost({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.type,
    required this.title,
    required this.body,
    this.tags = const [],
    this.status = statusActive,
    required this.createdAt,
    required this.updatedAt,
    this.upvoteCount = 0,
    this.commentCount = 0,
    this.isUpvoted = false,
  });

  bool get isQuestion => type == typeQuestion;
  bool get isTip => type == typeTip;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String? ?? '',
      authorUserId: json['authorUserId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      type: json['type'] as String? ?? typeTip,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tags: _parseStringList(json['tags']),
      status: json['status'] as String? ?? statusActive,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isUpvoted: _parseBool(json['isUpvoted']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorUserId': authorUserId,
      'authorName': authorName,
      'type': type,
      'title': title,
      'body': body,
      'tags': tags,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'upvoteCount': upvoteCount,
      'commentCount': commentCount,
      'isUpvoted': isUpvoted,
    };
  }

  CommunityPost copyWith({
    String? id,
    String? authorUserId,
    String? authorName,
    String? type,
    String? title,
    String? body,
    List<String>? tags,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? upvoteCount,
    int? commentCount,
    bool? isUpvoted,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorUserId: authorUserId ?? this.authorUserId,
      authorName: authorName ?? this.authorName,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      commentCount: commentCount ?? this.commentCount,
      isUpvoted: isUpvoted ?? this.isUpvoted,
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().where((item) => item.isNotEmpty).toList();
    }
    if (raw is String) {
      if (raw.trim().isEmpty) {
        return const [];
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
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

  static bool _parseBool(dynamic raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      return raw == '1' || raw.toLowerCase() == 'true';
    }
    return false;
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorUserId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorUserId: json['authorUserId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: CommunityPost._parseDate(json['createdAt']),
      updatedAt: CommunityPost._parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorUserId': authorUserId,
      'authorName': authorName,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
