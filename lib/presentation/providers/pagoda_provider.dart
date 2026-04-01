import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/logger.dart';
import '../../core/services/pagoda_search_service.dart';
import '../../data/models/pagoda_model.dart';
import '../../data/services/pagoda_data_service.dart';

class PagodaUIProvider with ChangeNotifier {
  PagodaUIProvider({
    PagodaDataService? dataService,
    PagodaSearchService? searchService,
  }) : _dataService = dataService ?? PagodaDataService(),
       _searchService = searchService ?? PagodaSearchService() {
    _currentOwnerId = _resolveOwnerId(_auth.currentUser);
    _authSub = _auth.authStateChanges().listen((user) async {
      final nextOwnerId = _resolveOwnerId(user);
      if (nextOwnerId == _currentOwnerId) {
        return;
      }
      _currentOwnerId = nextOwnerId;
      await loadPagodas();
      await loadFavorites();
    });
    loadPagodas();
    loadFavorites();
  }

  final PagodaDataService _dataService;
  final PagodaSearchService _searchService;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  List<Pagoda> _pagodas = [];
  List<Pagoda> _favorites = [];
  String _selectedCategory = '';
  String _searchQuery = '';
  bool _isLoading = false;
  String _currentOwnerId = AppConstants.guestOwnerId;
  StreamSubscription<firebase_auth.User?>? _authSub;

  List<Pagoda> get pagodas => _searchService.filterPagodas(
    pagodas: _pagodas,
    selectedCategory: _selectedCategory,
    searchQuery: _searchQuery,
  );
  List<Pagoda> get allPagodas => List.unmodifiable(_pagodas);
  List<Pagoda> get favorites => _favorites;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get canManageFavorites => _currentOwnerId != AppConstants.guestOwnerId;
  String get currentOwnerId => _currentOwnerId;

  String _resolveOwnerId(firebase_auth.User? user) {
    return user?.uid ?? AppConstants.guestOwnerId;
  }

  Future<void> loadPagodas() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pagodas = await _dataService.loadPagodas(
        ownerUserId: canManageFavorites ? _currentOwnerId : null,
      );
    } catch (e, stackTrace) {
      Logger.error('Error loading pagodas', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    try {
      if (!canManageFavorites) {
        _favorites = [];
      } else {
        _favorites = await _dataService.getFavorites(
          ownerUserId: _currentOwnerId,
        );
        unawaited(_syncFavoritesToCloud());
      }
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Error loading favorites', e, stackTrace);
    }
  }

  Future<void> toggleFavorite(String pagodaId) async {
    if (!canManageFavorites) return;

    final index = _pagodas.indexWhere((pagoda) => pagoda.id == pagodaId);
    if (index == -1) return;

    final previousPagoda = _pagodas[index];
    final nextPagoda = previousPagoda.copyWith(
      isFavorite: !previousPagoda.isFavorite,
    );
    _pagodas[index] = nextPagoda;

    if (nextPagoda.isFavorite) {
      _favorites.removeWhere((pagoda) => pagoda.id == pagodaId);
      _favorites.insert(0, nextPagoda);
    } else {
      _favorites.removeWhere((pagoda) => pagoda.id == pagodaId);
    }
    notifyListeners();

    try {
      await _dataService.toggleFavorite(pagodaId, ownerUserId: _currentOwnerId);
      unawaited(_syncFavoritesToCloud());
    } catch (e, stackTrace) {
      _pagodas[index] = previousPagoda;
      if (previousPagoda.isFavorite) {
        _favorites.removeWhere((pagoda) => pagoda.id == pagodaId);
        _favorites.insert(0, previousPagoda);
      } else {
        _favorites.removeWhere((pagoda) => pagoda.id == pagodaId);
      }
      notifyListeners();
      Logger.error('Error toggling favorite', e, stackTrace);
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<Pagoda?> getPagodaById(String id) {
    return _dataService.getPagodaById(
      id,
      ownerUserId: canManageFavorites ? _currentOwnerId : null,
    );
  }

  Future<void> _syncFavoritesToCloud() async {
    if (!canManageFavorites || !_firebaseService.isFirebaseAvailable) {
      return;
    }
    final favoriteIds = _favorites.map((pagoda) => pagoda.id).toList();
    try {
      await _firebaseService.syncFavorites(_currentOwnerId, favoriteIds);
    } catch (e, stackTrace) {
      Logger.error('Error syncing favorites to Firestore', e, stackTrace);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class PagodaProvider extends PagodaUIProvider {
  PagodaProvider({super.dataService, super.searchService});
}
