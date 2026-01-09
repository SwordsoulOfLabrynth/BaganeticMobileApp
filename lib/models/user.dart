// lib/models/user.dart

class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
      photoUrl: json['photoUrl'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class ActivitySummary {
  final int postsCreated;
  final int commentsPosted;

  ActivitySummary({required this.postsCreated, required this.commentsPosted});

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      postsCreated: json['postsCreated'],
      commentsPosted: json['commentsPosted'],
    );
  }
}
