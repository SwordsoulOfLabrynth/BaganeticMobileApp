import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firestore_instance.dart';
import '../../core/services/logger.dart';
import '../datasources/local_datasource.dart';
import '../models/community_post_model.dart';

class CommunityDataService {
  CommunityDataService({
    DatabaseService? databaseService,
    FirebaseFirestore? firestore,
  }) : _db = databaseService ?? DatabaseService(),
       _firestore = firestore ?? FirestoreInstance.instance;

  final DatabaseService _db;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection(AppConstants.communityPosts);

  Future<List<CommunityPost>> loadPosts({String? currentUserId}) async {
    final localPosts = await _safeLoadLocalPosts(currentUserId: currentUserId);

    try {
      return await _loadPostsFromFirestore(
        currentUserId: currentUserId,
        localPosts: localPosts,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Falling back to local posts',
        e,
        stackTrace,
      );
      return localPosts;
    }
  }

  Future<CommunityPost?> getPostById(String id, {String? currentUserId}) async {
    try {
      final snapshot = await _postsRef.doc(id).get();
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      final post = CommunityPost.fromJson({'id': snapshot.id, ...data});
      if (_shouldHidePost(post)) {
        return null;
      }
      final isUpvoted = await _isPostUpvotedByUser(
        postId: post.id,
        currentUserId: currentUserId,
      );
      return post.copyWith(isUpvoted: isUpvoted);
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Falling back to local post lookup',
        e,
        stackTrace,
      );
      return _db.getCommunityPostById(id, currentUserId: currentUserId);
    }
  }

  Future<List<CommunityComment>> loadComments(String postId) async {
    try {
      final snapshot = await _postsRef
          .doc(postId)
          .collection(AppConstants.communityComments)
          .orderBy('createdAt')
          .get();

      final comments = snapshot.docs
          .map(
            (doc) => CommunityComment.fromJson({'id': doc.id, ...doc.data()}),
          )
          .toList(growable: false);

      for (final comment in comments) {
        try {
          await _db.insertCommunityComment(comment);
        } catch (_) {}
      }

      return comments;
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Falling back to local comments',
        e,
        stackTrace,
      );
      return _db.getCommunityComments(postId);
    }
  }

  Future<void> createPost(CommunityPost post) async {
    try {
      await _postsRef.doc(post.id).set(_serializePost(post));
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Remote post create failed, caching locally',
        e,
        stackTrace,
      );
      await _db.insertCommunityPost(post);
      return;
    }

    try {
      await _db.insertCommunityPost(post);
    } catch (_) {}
  }

  Future<void> createComment(CommunityComment comment) async {
    final postRef = _postsRef.doc(comment.postId);
    final commentRef = postRef
        .collection(AppConstants.communityComments)
        .doc(comment.id);

    try {
      await _firestore.runTransaction((txn) async {
        txn.set(commentRef, _serializeComment(comment));
        txn.update(postRef, {
          'updatedAt': Timestamp.fromDate(comment.updatedAt),
          'commentCount': FieldValue.increment(1),
        });
      });
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Remote comment create failed, caching locally',
        e,
        stackTrace,
      );
      await _db.insertCommunityComment(comment);
      return;
    }

    try {
      await _db.insertCommunityComment(comment);
    } catch (_) {}
  }

  Future<void> toggleUpvote(String postId, {required String userId}) async {
    if (userId.isEmpty) {
      return;
    }

    final postRef = _postsRef.doc(postId);
    final voteRef = postRef
        .collection(AppConstants.communityPostVotes)
        .doc(userId);

    try {
      await _firestore.runTransaction((txn) async {
        final voteSnapshot = await txn.get(voteRef);
        if (voteSnapshot.exists) {
          txn.delete(voteRef);
          txn.update(postRef, {'upvoteCount': FieldValue.increment(-1)});
          return;
        }

        txn.set(voteRef, {
          'postId': postId,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(postRef, {'upvoteCount': FieldValue.increment(1)});
      });
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Remote upvote toggle failed, falling back locally',
        e,
        stackTrace,
      );
      await _db.toggleCommunityPostUpvote(postId, userId: userId);
      return;
    }

    try {
      await _db.toggleCommunityPostUpvote(postId, userId: userId);
    } catch (_) {}
  }

  Future<List<CommunityPost>> _loadPostsFromFirestore({
    String? currentUserId,
    List<CommunityPost>? localPosts,
  }) async {
    final snapshot = await _postsRef
        .where('status', isEqualTo: CommunityPost.statusActive)
        .get();
    final docs = snapshot.docs;
    Set<String> upvotedPostIds = const <String>{};
    try {
      upvotedPostIds = await _loadUpvotedPostIds(currentUserId: currentUserId);
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Failed to load remote vote state, continuing without it',
        e,
        stackTrace,
      );
    }

    final posts = docs
        .map((doc) => CommunityPost.fromJson({'id': doc.id, ...doc.data()}))
        .where((post) => !_shouldHidePost(post))
        .map(
          (post) => post.copyWith(isUpvoted: upvotedPostIds.contains(post.id)),
        )
        .toList(growable: false);

    for (final post in posts) {
      try {
        await _db.insertCommunityPost(post);
      } catch (_) {}
    }

    final resolvedUserId = _resolveSignedInUserId(currentUserId);
    if (resolvedUserId != null) {
      try {
        await _syncPendingLocalPosts(
          currentUserId: resolvedUserId,
          localPosts: localPosts ?? const [],
          remotePosts: posts,
        );
      } catch (e, stackTrace) {
        Logger.error(
          'CommunityDataService: Failed to sync pending local posts after remote load',
          e,
          stackTrace,
        );
      }
    }

    return _mergePosts(localPosts: localPosts ?? const [], remotePosts: posts);
  }

  Future<Set<String>> _loadUpvotedPostIds({String? currentUserId}) async {
    final resolvedUserId = currentUserId?.trim() ?? '';
    if (resolvedUserId.isEmpty || resolvedUserId == AppConstants.guestOwnerId) {
      return const <String>{};
    }

    final snapshot = await _firestore
        .collectionGroup(AppConstants.communityPostVotes)
        .where('userId', isEqualTo: resolvedUserId)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['postId'])
        .whereType<String>()
        .where((postId) => postId.isNotEmpty)
        .toSet();
  }

  Future<bool> _isPostUpvotedByUser({
    required String postId,
    String? currentUserId,
  }) async {
    final upvotedIds = await _loadUpvotedPostIds(currentUserId: currentUserId);
    return upvotedIds.contains(postId);
  }

  bool _shouldHidePost(CommunityPost post) {
    return post.status != CommunityPost.statusActive;
  }

  Future<List<CommunityPost>> _safeLoadLocalPosts({
    String? currentUserId,
  }) async {
    try {
      return await _db.getCommunityPosts(currentUserId: currentUserId);
    } catch (e, stackTrace) {
      Logger.error(
        'CommunityDataService: Failed to load local posts',
        e,
        stackTrace,
      );
      return const [];
    }
  }

  String? _resolveSignedInUserId(String? currentUserId) {
    final resolvedUserId = currentUserId?.trim() ?? '';
    if (resolvedUserId.isEmpty || resolvedUserId == AppConstants.guestOwnerId) {
      return null;
    }
    return resolvedUserId;
  }

  Future<void> _syncPendingLocalPosts({
    required String currentUserId,
    required List<CommunityPost> localPosts,
    required List<CommunityPost> remotePosts,
  }) async {
    final ownedLocalPosts = localPosts
        .where(
          (post) =>
              post.authorUserId == currentUserId && !_shouldHidePost(post),
        )
        .toList(growable: false);
    if (ownedLocalPosts.isEmpty) {
      return;
    }

    final remotePostIds = remotePosts.map((post) => post.id).toSet();

    for (final post in ownedLocalPosts) {
      if (remotePostIds.contains(post.id)) {
        continue;
      }
      try {
        await _postsRef.doc(post.id).set(_serializePost(post));
        remotePostIds.add(post.id);
      } catch (e, stackTrace) {
        Logger.error(
          'CommunityDataService: Failed to sync cached local post to Firestore',
          e,
          stackTrace,
        );
      }
    }
  }

  List<CommunityPost> _mergePosts({
    required List<CommunityPost> localPosts,
    required List<CommunityPost> remotePosts,
  }) {
    final mergedById = <String, CommunityPost>{};

    for (final post in localPosts) {
      if (_shouldHidePost(post)) {
        continue;
      }
      mergedById[post.id] = post;
    }

    for (final post in remotePosts) {
      final existing = mergedById[post.id];
      if (existing == null ||
          post.updatedAt.isAfter(existing.updatedAt) ||
          post.updatedAt.isAtSameMomentAs(existing.updatedAt)) {
        mergedById[post.id] = post;
      }
    }

    final merged = mergedById.values.toList(growable: false)
      ..sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) {
          return updatedCompare;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return merged;
  }

  Map<String, dynamic> _serializePost(CommunityPost post) {
    return {
      'id': post.id,
      'authorUserId': post.authorUserId,
      'authorName': post.authorName,
      'type': post.type,
      'title': post.title,
      'body': post.body,
      'tags': post.tags,
      'status': post.status,
      'createdAt': Timestamp.fromDate(post.createdAt),
      'updatedAt': Timestamp.fromDate(post.updatedAt),
      'upvoteCount': post.upvoteCount,
      'commentCount': post.commentCount,
    };
  }

  Map<String, dynamic> _serializeComment(CommunityComment comment) {
    return {
      'id': comment.id,
      'postId': comment.postId,
      'authorUserId': comment.authorUserId,
      'authorName': comment.authorName,
      'body': comment.body,
      'createdAt': Timestamp.fromDate(comment.createdAt),
      'updatedAt': Timestamp.fromDate(comment.updatedAt),
    };
  }
}
