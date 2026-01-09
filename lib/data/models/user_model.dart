class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> favoriteIds;
  final DateTime createdAt;
  
  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.favoriteIds = const [],
    required this.createdAt,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      favoriteIds: (json['favoriteIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'favoriteIds': favoriteIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
