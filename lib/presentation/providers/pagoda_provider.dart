import 'package:flutter/material.dart';

import '../../core/services/logger.dart';
import '../../core/services/pagoda_search_service.dart';
import '../../data/models/pagoda_model.dart';
import '../../data/services/pagoda_data_service.dart';

class PagodaUIProvider with ChangeNotifier {
  PagodaUIProvider({
    PagodaDataService? dataService,
    PagodaSearchService? searchService,
  })  : _dataService = dataService ?? PagodaDataService(),
        _searchService = searchService ?? PagodaSearchService() {
    loadPagodas();
    loadFavorites();
  }

  final PagodaDataService _dataService;
  final PagodaSearchService _searchService;

  List<Pagoda> _pagodas = [];
  List<Pagoda> _favorites = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  List<Pagoda> get pagodas => _searchService.filterPagodas(
        pagodas: _pagodas,
        selectedCategory: _selectedCategory,
        searchQuery: _searchQuery,
      );
  List<Pagoda> get allPagodas => List.unmodifiable(_pagodas);
  List<Pagoda> get favorites => _favorites;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  Future<void> loadPagodas() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pagodas = await _dataService.loadPagodas();
    } catch (e, stackTrace) {
      Logger.error('Error loading pagodas', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadSampleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _dataService.reloadSampleData();
      _pagodas = await _dataService.loadPagodas();
      _favorites = await _dataService.getFavorites();
    } catch (e, stackTrace) {
      Logger.error('Error reloading sample data', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    try {
      _favorites = await _dataService.getFavorites();
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Error loading favorites', e, stackTrace);
    }
  }

  Future<void> toggleFavorite(String pagodaId) async {
    try {
      await _dataService.toggleFavorite(pagodaId);
      await loadPagodas();
      await loadFavorites();
    } catch (e, stackTrace) {
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
    return _dataService.getPagodaById(id);
  }
}

class PagodaProvider extends PagodaUIProvider {
  PagodaProvider({
    PagodaDataService? dataService,
    PagodaSearchService? searchService,
  }) : super(dataService: dataService, searchService: searchService);
}
