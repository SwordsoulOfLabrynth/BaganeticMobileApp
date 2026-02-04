import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/chat_repository.dart';

class ChatMembershipProvider with ChangeNotifier {
  ChatMembershipProvider(this._repository);

  final ChatRepository _repository;

  StreamSubscription<Set<String>>? _subscription;
  Set<String> _memberGroupIds = const {};
  bool _isLoading = true;
  Object? _error;
  bool _isStarted = false;

  Set<String> get memberGroupIds => _memberGroupIds;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _repository.watchMyGroupIds().listen(
      (groupIds) {
        _memberGroupIds = groupIds;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _error = error;
        notifyListeners();
      },
    );
  }

  void restart() {
    _subscription?.cancel();
    _isStarted = false;
    _memberGroupIds = const {};
    start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
