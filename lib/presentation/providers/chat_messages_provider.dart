import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

class ChatMessagesProvider with ChangeNotifier {
  ChatMessagesProvider(
    this._repository, {
    required this.groupId,
    this.liveLimit = 40,
    this.pageSize = 40,
  });

  final ChatRepository _repository;
  final String groupId;
  final int liveLimit;
  final int pageSize;

  StreamSubscription<List<ChatMessage>>? _liveSubscription;
  List<ChatMessage> _liveMessages = const [];
  final Map<String, ChatMessage> _olderMessages = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSending = false;
  Object? _loadError;
  Object? _sendError;
  ChatMessagesCursor? _nextCursor;
  bool _isStarted = false;
  Timer? _loadingTimeout;

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  List<ChatMessage> get messages => _mergedMessages();
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isSending => _isSending;
  Object? get loadError => _loadError;
  Object? get sendError => _sendError;

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    _setLoading(true);

    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (_isLoading) {
        _setLoading(false);
        _loadError =
            'Timeout: Unable to load messages. Please check your connection.';
        notifyListeners();
      }
    });

    _liveSubscription = _repository
        .watchMessages(groupId: groupId, limit: liveLimit)
        .listen(
          (liveMessages) {
            _loadingTimeout?.cancel();
            final wasLoading = _isLoading;
            _liveMessages = liveMessages;
            if (_olderMessages.isEmpty && _loadError == null) {
              _hasMore = liveMessages.length >= liveLimit;
            }
            _nextCursor = _cursorFromLastMessage();
            _loadError = null;
            _setLoading(false);

            // `_setLoading(false)` only notifies when loading state changes.
            // We still need to notify for realtime message updates.
            if (!wasLoading) {
              notifyListeners();
            }
          },
          onError: (error) {
            _loadingTimeout?.cancel();
            _setLoading(false);
            _loadError = error;
            notifyListeners();
          },
        );
  }

  void restart() {
    _loadingTimeout?.cancel();
    _liveSubscription?.cancel();
    _isStarted = false;
    _liveMessages = const [];
    _olderMessages.clear();
    _hasMore = true;
    _nextCursor = null;
    _loadError = null;
    _sendError = null;
    start();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) {
      return;
    }

    _isLoadingMore = true;
    _loadError = null;
    notifyListeners();

    try {
      final page = await _repository.fetchMessagesPage(
        groupId: groupId,
        cursor: _nextCursor,
        limit: pageSize,
      );
      final liveIds = _liveMessages.map((message) => message.id).toSet();
      for (final message in page.items) {
        if (!liveIds.contains(message.id)) {
          _olderMessages[message.id] = message;
        }
      }
      _nextCursor = page.nextCursor ?? _cursorFromLastMessage();
      _hasMore = page.hasMore && page.items.isNotEmpty;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (_isSending) {
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      // Add timeout for sending messages
      await _repository
          .sendMessage(groupId, trimmed)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Message send timeout'),
          );
    } catch (error) {
      _sendError = error;
      rethrow;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  ChatMessagesCursor? _cursorFromLastMessage() {
    final allMessages = _mergedMessages();
    if (allMessages.isEmpty) {
      return null;
    }
    final last = allMessages.last;
    return ChatMessagesCursor(
      sentAt: last.sentAt ?? ChatRepository.minCursorDate,
      messageId: last.id,
    );
  }

  List<ChatMessage> _mergedMessages() {
    final merged = <String, ChatMessage>{
      for (final message in _olderMessages.values) message.id: message,
      for (final message in _liveMessages) message.id: message,
    }.values.toList();

    merged.sort((a, b) {
      final aDate = a.sentAt ?? ChatRepository.minCursorDate;
      final bDate = b.sentAt ?? ChatRepository.minCursorDate;
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
    _loadingTimeout?.cancel();
    _liveSubscription?.cancel();
    super.dispose();
  }
}
