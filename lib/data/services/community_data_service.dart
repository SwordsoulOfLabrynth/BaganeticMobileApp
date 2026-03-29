import '../datasources/local_datasource.dart';
import '../models/community_post_model.dart';

class CommunityDataService {
  CommunityDataService({DatabaseService? databaseService})
    : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;

  Future<List<CommunityPost>> loadPosts({String? currentUserId}) {
    return _db.getCommunityPosts(currentUserId: currentUserId);
  }

  Future<CommunityPost?> getPostById(String id, {String? currentUserId}) {
    return _db.getCommunityPostById(id, currentUserId: currentUserId);
  }

  Future<List<CommunityComment>> loadComments(String postId) {
    return _db.getCommunityComments(postId);
  }

  Future<void> createPost(CommunityPost post) {
    return _db.insertCommunityPost(post);
  }

  Future<void> createComment(CommunityComment comment) {
    return _db.insertCommunityComment(comment);
  }

  Future<void> toggleUpvote(String postId, {required String userId}) {
    return _db.toggleCommunityPostUpvote(postId, userId: userId);
  }
}
