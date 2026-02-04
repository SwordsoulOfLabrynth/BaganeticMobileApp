import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/chat_repository.dart';

class ChatMemberDataProvider with ChangeNotifier {
  ChatMemberDataProvider(this._repository);

  final ChatRepository _repository;

  StreamSubscription<Map<String, int>>? _subscription;
  List<String> _targetGroupIds = const [];
  Map<String, int> _memberCounts = const {};
  bool _isLoading = false;
  Object? _error;

  Map<String, int> get memberCounts => _memberCounts;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  void watchGroups(List<String> groupIds) {
    final normalized = groupIds.toSet().where((id) => id.isNotEmpty).toList()
      ..sort();

    if (listEquals(normalized, _targetGroupIds)) {
      return;
    }

    _targetGroupIds = normalized;
    _subscription?.cancel();

    if (normalized.isEmpty) {
      _memberCounts = const {};
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _repository
        .watchMemberCountsForGroups(normalized)
        .listen(
          (counts) {
            _memberCounts = counts;
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

  int? countForGroup(String groupId) => _memberCounts[groupId];

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
