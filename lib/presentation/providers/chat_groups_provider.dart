import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/chat_group.dart';
import '../../data/repositories/chat_repository.dart';

class ChatGroupsProvider with ChangeNotifier {
  ChatGroupsProvider(
    this._repository, {
    this.liveLimit = 20,
    this.pageSize = 20,
  });

  final ChatRepository _repository;
  final int liveLimit;
  final int pageSize;

  StreamSubscription<List<ChatGroup>>? _liveSubscription;
  List<ChatGroup> _liveGroups = const [];
  final Map<String, ChatGroup> _olderGroups = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;
  ChatGroupsCursor? _nextCursor;
  bool _isStarted = false;

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  List<ChatGroup> get groups => _mergedGroups();
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    _setLoading(true);

    _liveSubscription = _repository
        .watchGroups(limit: liveLimit)
        .listen(
          (liveGroups) {
            _liveGroups = liveGroups;
            if (_olderGroups.isEmpty && _error == null) {
              _hasMore = liveGroups.length >= liveLimit;
            }
            _nextCursor = _cursorFromLastGroup();
            _setLoading(false);
            _error = null;
          },
          onError: (error) {
            _setLoading(false);
            _error = error;
            notifyListeners();
          },
        );
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) {
      return;
    }

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _repository.fetchGroupsPage(
        cursor: _nextCursor,
        limit: pageSize,
      );
      final liveIds = _liveGroups.map((group) => group.id).toSet();
      for (final group in page.items) {
        if (!liveIds.contains(group.id)) {
          _olderGroups[group.id] = group;
        }
      }
      _nextCursor = page.nextCursor ?? _cursorFromLastGroup();
      _hasMore = page.hasMore && page.items.isNotEmpty;
    } catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  ChatGroupsCursor? _cursorFromLastGroup() {
    final allGroups = _mergedGroups();
    if (allGroups.isEmpty) {
      return null;
    }
    final last = allGroups.last;
    return ChatGroupsCursor(
      lastMessageAt: last.lastMessageAt ?? ChatRepository.minCursorDate,
      groupId: last.id,
    );
  }

  List<ChatGroup> _mergedGroups() {
    final merged = <String, ChatGroup>{
      for (final group in _olderGroups.values) group.id: group,
      for (final group in _liveGroups) group.id: group,
    }.values.toList();

    merged.sort((a, b) {
      final aDate = a.lastMessageAt ?? ChatRepository.minCursorDate;
      final bDate = b.lastMessageAt ?? ChatRepository.minCursorDate;
      final dateComparison = bDate.compareTo(aDate);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return b.id.compareTo(a.id);
    });

    return merged;
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}
