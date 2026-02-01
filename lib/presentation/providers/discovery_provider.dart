import 'package:flutter/material.dart';

import '../../core/services/discovery_search_service.dart';
import '../../core/services/logger.dart';
import '../../data/models/discovery_item.dart';
import '../../data/services/discovery_data_service.dart';

class DiscoveryProvider with ChangeNotifier {
  DiscoveryProvider({
    DiscoveryDataService? dataService,
    DiscoverySearchService? searchService,
  })  : _dataService = dataService ?? DiscoveryDataService(),
        _searchService = searchService ?? DiscoverySearchService() {
    loadItems();
  }

  final DiscoveryDataService _dataService;
  final DiscoverySearchService _searchService;

  List<DiscoveryItem> _items = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  List<DiscoveryItem> get items => _searchService.filterItems(
        items: _items,
        selectedCategory: _selectedCategory,
        searchQuery: _searchQuery,
      );
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _dataService.loadItems();
    } catch (e, stackTrace) {
      Logger.error('Error loading discovery items', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
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
}
