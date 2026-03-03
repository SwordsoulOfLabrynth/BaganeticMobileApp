class PagodaFeedback {
  final String id;
  final String pagodaId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  PagodaFeedback({
    required this.id,
    required this.pagodaId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory PagodaFeedback.fromJson(Map<String, dynamic> json) {
    return PagodaFeedback(
      id: json['id'] as String,
      pagodaId: json['pagodaId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pagodaId': pagodaId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PagodaFeedback copyWith({
    String? id,
    String? pagodaId,
    String? userId,
    String? userName,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return PagodaFeedback(
      id: id ?? this.id,
      pagodaId: pagodaId ?? this.pagodaId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
