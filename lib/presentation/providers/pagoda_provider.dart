import 'package:flutter/material.dart';
import '../../data/models/pagoda_model.dart';
import '../../data/datasources/local_datasource.dart';
import '../../core/utils/image_path_utils.dart';

class PagodaProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  
  List<Pagoda> _pagodas = [];
  List<Pagoda> _favorites = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  
  List<Pagoda> get pagodas => _filteredPagodas();
  List<Pagoda> get favorites => _favorites;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  
  PagodaProvider() {
    loadPagodas();
    loadFavorites();
  }
  
  Future<void> loadPagodas() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pagodas = await _db.getAllPagodas();
      print('Loaded ${_pagodas.length} pagodas from database');

      // If no pagodas in DB, initialize with sample data
      if (_pagodas.isEmpty) {
        print('Database is empty, initializing with sample data...');
        await _initializeSampleData();
        _pagodas = await _db.getAllPagodas();
        print('Initialized ${_pagodas.length} pagodas with sample data');
      } else {
        // Log first pagoda's image URL for debugging
        if (_pagodas.isNotEmpty) {
          print('First pagoda image URL: ${_pagodas.first.imageUrl}');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading pagodas: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to force reload sample data (for development/testing)
  Future<void> reloadSampleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear existing data
      await _db.clearAllData();

      // Initialize with new sample data
      await _initializeSampleData();
      _pagodas = await _db.getAllPagodas();
      _favorites = await _db.getFavorites();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error reloading sample data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadFavorites() async {
    try {
      _favorites = await _db.getFavorites();
      notifyListeners();
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }
  
  Future<void> toggleFavorite(String pagodaId) async {
    try {
      await _db.toggleFavorite(pagodaId);
      await loadPagodas();
      await loadFavorites();
    } catch (e) {
      print('Error toggling favorite: $e');
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
  
  List<Pagoda> _filteredPagodas() {
    var filtered = _pagodas;
    
    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return filtered;
  }
  
  Future<Pagoda?> getPagodaById(String id) async {
    return await _db.getPagodaById(id);
  }
  
  Future<void> _initializeSampleData() async {
    // Sample pagoda data using local assets - paths are normalized when inserted
    final samplePagodas = [
      Pagoda(
        id: 'ananda',
        name: 'Ananda Temple',
        description: 'One of the finest, largest, best preserved and most revered temples in Bagan.',
        category: 'Temple',
        latitude: 21.1751,
        longitude: 94.8683,
        imageUrl: ImagePathUtils.normalizeImagePath('assets/images/pagodas/Ananda Temple/ananda-temple-4899166_1280.jpg'),
        historicalInfo: 'Built in 1105 AD by King Kyanzittha.',
        architecturalStyle: 'Mon architecture',
        yearBuilt: 1105,
      ),
      Pagoda(
        id: 'shwezigon',
        name: 'Shwezigon Pagoda',
        description: 'A Buddhist stupa located in Nyaung-U, a town near Bagan.',
        category: 'Pagoda',
        latitude: 21.1777,
        longitude: 94.9063,
        imageUrl: 'assets/images/pagodas/Shwezigon Pagoda/554d48e8ef6872ac2d7ab2b86b6c3ad3.jpg',
        historicalInfo: 'Construction began in 1059 under King Anawrahta.',
        architecturalStyle: 'Burmese Buddhist',
        yearBuilt: 1059,
      ),
      Pagoda(
        id: 'dhammayangyi',
        name: 'Dhammayangyi Temple',
        description: 'The largest of all the temples in Bagan.',
        category: 'Temple',
        latitude: 21.1633,
        longitude: 94.8722,
        imageUrl: 'assets/images/pagodas/Dhammayangyi Temple/Dhammayangyi_Temple_at_Bagan,Myanmar.jpg',
        historicalInfo: 'Built during the reign of King Narathu (1167-1170).',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1170,
      ),
      Pagoda(
        id: 'thatbyinnyu',
        name: 'Thatbyinnyu Temple',
        description: 'The tallest temple in Bagan, standing at 66 meters.',
        category: 'Temple',
        latitude: 21.1711,
        longitude: 94.8644,
        imageUrl: 'assets/images/pagodas/Thatbyinnyu Temple/df0ebad94c9d9d41e52b1d2c74fdead2.jpg',
        historicalInfo: 'Built in 1144 during the reign of King Alaungsithu.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1144,
      ),
      Pagoda(
        id: 'htilominlo',
        name: 'Htilominlo Temple',
        description: 'A Buddhist temple in Bagan, built during the reign of King Htilominlo.',
        category: 'Temple',
        latitude: 21.1828,
        longitude: 94.8983,
        imageUrl: 'assets/images/pagodas/Htilominlo Temple/dee6e00eeb4074ee20f833988c05180f.jpg',
        historicalInfo: 'Constructed in 1218 AD.',
        architecturalStyle: 'Late Bagan style',
        yearBuilt: 1218,
      ),
      Pagoda(
        id: 'alodawpyae',
        name: 'Alodawpyae Pagoda',
        description: 'A beautiful pagoda in Bagan known for its architecture.',
        category: 'Pagoda',
        latitude: 21.1689,
        longitude: 94.8656,
        imageUrl: 'assets/images/pagodas/Alodawpyae Pagoda/Alodawpyi_Pagoda.jpg',
        historicalInfo: 'Built during the Bagan period.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1100,
      ),
      Pagoda(
        id: 'bupaya',
        name: 'Bu Paya',
        description: 'An ancient pagoda in Bagan with rich history.',
        category: 'Pagoda',
        latitude: 21.1722,
        longitude: 94.8678,
        imageUrl: 'assets/images/pagodas/BuPaya/Bupaya-Pagoda-and-Irrawaddy-in-the-back.jpg',
        historicalInfo: 'One of the oldest pagodas in Bagan.',
        architecturalStyle: 'Early Bagan style',
        yearBuilt: 850,
      ),
      Pagoda(
        id: 'dhammayazaka',
        name: 'Dhammayazaka',
        description: 'A significant temple in the Bagan archaeological zone.',
        category: 'Temple',
        latitude: 21.1694,
        longitude: 94.8667,
        imageUrl: 'assets/images/pagodas/Dhammayazaka/dhammayazika-pagoda-l.jpg',
        historicalInfo: 'Built during the golden age of Bagan.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1196,
      ),
      Pagoda(
        id: 'gawdawpalin',
        name: 'Gawdawpalin Temple',
        description: 'A large temple complex in Bagan.',
        category: 'Temple',
        latitude: 21.1733,
        longitude: 94.8694,
        imageUrl: 'assets/images/pagodas/Gawdawpalin Temple/istockphoto-479621119-612x612.jpg',
        historicalInfo: 'Constructed in the 12th century.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1200,
      ),
      Pagoda(
        id: 'gubyaukgyi',
        name: 'Gu Byauk Gyi Pagoda',
        description: 'A well-preserved pagoda in Bagan.',
        category: 'Pagoda',
        latitude: 21.1747,
        longitude: 94.8708,
        imageUrl: 'assets/images/pagodas/Gu Byauk Gyi Pagoda/gubyaukgyi-temple.jpg',
        historicalInfo: 'Built in the 12th century.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1113,
      ),
      Pagoda(
        id: 'izagawna',
        name: 'Iza Gawna Pagoda',
        description: 'A historic pagoda in the Bagan area.',
        category: 'Pagoda',
        latitude: 21.1761,
        longitude: 94.8722,
        imageUrl: 'assets/images/pagodas/Iza Gawna Pagoda/normal_iza_gawna_pagoda__bagan.jpg',
        historicalInfo: 'Part of Bagan\'s rich heritage.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1050,
      ),
      Pagoda(
        id: 'lawkananda',
        name: 'Lawkananda Pagoda',
        description: 'A prominent pagoda in Bagan.',
        category: 'Pagoda',
        latitude: 21.1775,
        longitude: 94.8736,
        imageUrl: 'assets/images/pagodas/Lawkananda Pagoda/20102959715_e7e032d5af_b.jpg',
        historicalInfo: 'Built during the Bagan dynasty.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1070,
      ),
      Pagoda(
        id: 'mahezedi',
        name: 'Mahezedi Pagoda',
        description: 'A large stupa in Bagan.',
        category: 'Pagoda',
        latitude: 21.1789,
        longitude: 94.8750,
        imageUrl: 'assets/images/pagodas/Mahezedi Pagoda/Mahazedi_Pagoda_(Bagan).jpg',
        historicalInfo: 'Constructed in the 13th century.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1230,
      ),
      Pagoda(
        id: 'manuha',
        name: 'Manuha Temple',
        description: 'A temple built by King Manuha.',
        category: 'Temple',
        latitude: 21.1803,
        longitude: 94.8764,
        imageUrl: 'assets/images/pagodas/Manuha/Manuha-Paya-1.jpg',
        historicalInfo: 'Built by King Manuha in 1059.',
        architecturalStyle: 'Mon architecture',
        yearBuilt: 1059,
      ),
      Pagoda(
        id: 'pyathetgyi',
        name: 'Pyathetgyi Temple',
        description: 'A temple with unique architecture.',
        category: 'Temple',
        latitude: 21.1817,
        longitude: 94.8778,
        imageUrl: 'assets/images/pagodas/Pyathetgyi/Pyathadar-Pyathatgyi-Temple.jpg',
        historicalInfo: 'Built in the 13th century.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1280,
      ),
      Pagoda(
        id: 'seinnyetnyiama',
        name: 'Sein Nyet Nyi Ama Gu Phaya',
        description: 'A pagoda with beautiful surroundings.',
        category: 'Pagoda',
        latitude: 21.1831,
        longitude: 94.8792,
        imageUrl: 'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/Seinnyet-Nyima-Seinnyet-Ama-Paya-Bagan-Myanmar.jpg',
        historicalInfo: 'Part of Bagan\'s temple complex.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1100,
      ),
      Pagoda(
        id: 'shwegugyi',
        name: 'Shwe Gu Gyi',
        description: 'A golden pagoda in Bagan.',
        category: 'Pagoda',
        latitude: 21.1844,
        longitude: 94.8806,
        imageUrl: 'assets/images/pagodas/Shwe Gu Gyi/Shwegugyi-Temple-1-600x400.jpg',
        historicalInfo: 'Known for its golden appearance.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1150,
      ),
      Pagoda(
        id: 'sulamani',
        name: 'Sulamani Temple',
        description: 'One of the most beautiful temples in Bagan.',
        category: 'Temple',
        latitude: 21.1858,
        longitude: 94.8820,
        imageUrl: 'assets/images/pagodas/Sulamani Temple/sulamani-temple-bagan-myanmar-sunset-asia-82328684.webp',
        historicalInfo: 'Built in 1183.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1183,
      ),
      Pagoda(
        id: 'thambula',
        name: 'Thambula Temple',
        description: 'A temple with intricate carvings.',
        category: 'Temple',
        latitude: 21.1872,
        longitude: 94.8834,
        imageUrl: 'assets/images/pagodas/Thambula/thambula-temple.jpg',
        historicalInfo: 'Built in the 13th century.',
        architecturalStyle: 'Bagan architecture',
        yearBuilt: 1255,
      ),
    ];

    for (var pagoda in samplePagodas) {
      await _db.insertPagoda(pagoda);
    }
  }
}
