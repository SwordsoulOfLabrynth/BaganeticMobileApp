import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/logger.dart';
import '../../data/models/community_post_model.dart';
import '../../data/services/community_data_service.dart';

enum CommunityFeedSort { latest, helpful }

class CommunityProvider extends ChangeNotifier {
  CommunityProvider({
    CommunityDataService? dataService,
    FirebaseService? firebaseService,
  }) : _dataService = dataService ?? CommunityDataService(),
       _firebaseService = firebaseService ?? FirebaseService() {
    _currentUserId = _resolveUserId(_firebaseService.currentUser?.uid);
    _authSub = _firebaseService.authStateChanges.listen((user) async {
      final nextUserId = _resolveUserId(user?.uid);
      if (nextUserId == _currentUserId) {
        return;
      }
      _currentUserId = nextUserId;
      await loadPosts();
    });
    loadPosts();
  }

  static const List<String> suggestedTags = [
    'sunrise',
    'transport',
    'food',
    'ticket',
    'safety',
    'photography',
  ];

  final CommunityDataService _dataService;
  final FirebaseService _firebaseService;

  List<CommunityPost> _allPosts = [];
  final Map<String, List<CommunityComment>> _commentsByPostId = {};
  final Set<String> _loadingCommentsPostIds = {};
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedTag = 'all';
  CommunityFeedSort _sort = CommunityFeedSort.latest;
  String _currentUserId = AppConstants.guestOwnerId;
  StreamSubscription<dynamic>? _authSub;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedType => _selectedType;
  String get selectedTag => _selectedTag;
  CommunityFeedSort get sort => _sort;
  bool get canInteract => _currentUserId != AppConstants.guestOwnerId;
  List<CommunityPost> get allPosts => List.unmodifiable(_allPosts);

  List<CommunityPost> get posts {
    var filtered = _allPosts
        .where((post) {
          final matchesType =
              _selectedType == 'all' || post.type == _selectedType;
          final matchesTag =
              _selectedTag == 'all' || post.tags.contains(_selectedTag);
          final q = _searchQuery.trim().toLowerCase();
          final matchesQuery =
              q.isEmpty ||
              post.title.toLowerCase().contains(q) ||
              post.body.toLowerCase().contains(q) ||
              post.authorName.toLowerCase().contains(q) ||
              post.tags.any((tag) => tag.toLowerCase().contains(q));
          return matchesType && matchesTag && matchesQuery;
        })
        .toList(growable: false);

    if (_sort == CommunityFeedSort.helpful) {
      filtered = [...filtered]
        ..sort((a, b) {
          final votesCompare = b.upvoteCount.compareTo(a.upvoteCount);
          if (votesCompare != 0) {
            return votesCompare;
          }
          final commentsCompare = b.commentCount.compareTo(a.commentCount);
          if (commentsCompare != 0) {
            return commentsCompare;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });
      return filtered;
    }

    filtered = [...filtered]
      ..sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) {
          return updatedCompare;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return filtered;
  }

  List<String> get availableTags {
    final merged = <String>{...suggestedTags};
    for (final post in _allPosts) {
      merged.addAll(post.tags);
    }
    final tags = merged.toList(growable: false)..sort();
    return ['all', ...tags];
  }

  List<CommunityComment> commentsForPost(String postId) {
    return _commentsByPostId[postId] ?? const [];
  }

  bool isCommentsLoading(String postId) {
    return _loadingCommentsPostIds.contains(postId);
  }

  CommunityPost? postById(String postId) {
    for (final post in _allPosts) {
      if (post.id == postId) {
        return post;
      }
    }
    return null;
  }

  Future<void> loadPosts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allPosts = await _dataService.loadPosts(currentUserId: _currentUserId);
    } catch (e, stackTrace) {
      Logger.error('Error loading community posts', e, stackTrace);
      _allPosts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadComments(String postId) async {
    _loadingCommentsPostIds.add(postId);
    notifyListeners();
    try {
      _commentsByPostId[postId] = await _dataService.loadComments(postId);
    } catch (e, stackTrace) {
      Logger.error('Error loading community comments', e, stackTrace);
      _commentsByPostId[postId] = const [];
    } finally {
      _loadingCommentsPostIds.remove(postId);
      notifyListeners();
    }
  }

  Future<void> createPost(CommunityPost post) async {
    await _dataService.createPost(post);
    await loadPosts();
  }

  Future<void> addComment(CommunityComment comment) async {
    await _dataService.createComment(comment);
    await Future.wait([loadPosts(), loadComments(comment.postId)]);
  }

  Future<void> toggleUpvote(String postId) async {
    if (!canInteract) {
      return;
    }

    final index = _allPosts.indexWhere((post) => post.id == postId);
    CommunityPost? previousPost;

    if (index != -1) {
      previousPost = _allPosts[index];
      final nextIsUpvoted = !previousPost.isUpvoted;
      final nextUpvoteCount = nextIsUpvoted
          ? previousPost.upvoteCount + 1
          : previousPost.upvoteCount > 0
          ? previousPost.upvoteCount - 1
          : 0;
      _allPosts[index] = previousPost.copyWith(
        isUpvoted: nextIsUpvoted,
        upvoteCount: nextUpvoteCount,
      );
      notifyListeners();
    }

    try {
      await _dataService.toggleUpvote(postId, userId: _currentUserId);
      unawaited(loadPosts());
    } catch (e, stackTrace) {
      if (index != -1 && previousPost != null) {
        _allPosts[index] = previousPost;
        notifyListeners();
      }
      Logger.error('Error toggling community upvote', e, stackTrace);
      rethrow;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedType(String value) {
    _selectedType = value;
    notifyListeners();
  }

  void setSelectedTag(String value) {
    _selectedTag = value;
    notifyListeners();
  }

  void setSort(CommunityFeedSort value) {
    _sort = value;
    notifyListeners();
  }

  String _resolveUserId(String? uid) {
    return uid?.isNotEmpty == true ? uid! : AppConstants.guestOwnerId;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
