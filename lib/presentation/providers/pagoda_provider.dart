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
  List<Pagoda> get allPagodas => List.unmodifiable(_pagodas);
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

    } catch (e) {
      print('Error loading pagodas: $e');
    } finally {
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

    } catch (e) {
      print('Error reloading sample data: $e');
    } finally {
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

    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
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
        description: 'One of the finest, largest, best preserved and most revered temples in Bagan. The Ananda Temple is a masterpiece of Mon architecture, featuring a perfect cruciform ground plan and four standing Buddha images facing the cardinal directions. It represents the peak of early Bagan temple architecture and is considered one of the most important pilgrimage sites in Myanmar.',
        category: 'Temple',
        latitude: 21.170806,
        longitude: 94.867856,
        imageUrl: ImagePathUtils.normalizeImagePath('assets/images/pagodas/Ananda Temple/ananda-temple-4899166_1280.jpg'),
        images: [
          'assets/images/pagodas/Ananda Temple/ananda-temple-4899166_1280.jpg',
          'assets/images/pagodas/Ananda Temple/4c22367f6cb8817335af727fc457d8e6.jpg',
          'assets/images/pagodas/Ananda Temple/Ananda-Temple-in-Bagan-1000x565.jpg',
          'assets/images/pagodas/Ananda Temple/e0122f8fcc8e7b0de1b14a20795e86a5.jpg',
        ],
        historicalInfo: 'Built in 1105 AD by King Kyanzittha of the Pagan Dynasty. The temple was constructed to commemorate the king\'s victory and to house sacred relics. According to legend, eight monks from India visited the king and described the Nandamula Cave in the Himalayas, inspiring the temple\'s design. The Ananda Temple has survived numerous earthquakes and remains one of the most intact structures from the Bagan period. It underwent major restoration in 1990 and continues to be an active place of worship.',
        architecturalStyle: 'Mon architecture with Indian influence. Features a perfect cruciform ground plan, four standing Buddha statues (each 9.5 meters tall), two inner ambulatories, and a central cube topped by a spire reaching 51 meters. The temple combines Mon and Indian architectural elements, with intricate stucco decorations and glazed terracotta plaques depicting Jataka tales.',
        yearBuilt: 1105,
      ),
      Pagoda(
        id: 'shwezigon',
        name: 'Shwezigon Pagoda',
        description: 'A magnificent Buddhist stupa located in Nyaung-U, a town near Bagan. The Shwezigon Pagoda is one of the most important religious sites in Myanmar, serving as a prototype for many later Burmese stupas. It houses a replica of the Buddha\'s tooth relic and is considered the most sacred pagoda in Bagan.',
        category: 'Pagoda',
        latitude: 21.195278,
        longitude: 94.893889,
        imageUrl: 'assets/images/pagodas/Shwezigon Pagoda/554d48e8ef6872ac2d7ab2b86b6c3ad3.jpg',
        images: [
          'assets/images/pagodas/Shwezigon Pagoda/554d48e8ef6872ac2d7ab2b86b6c3ad3.jpg',
          'assets/images/pagodas/Shwezigon Pagoda/1a1afe376333f59c9bb72dbf35c2e9c9.jpg',
          'assets/images/pagodas/Shwezigon Pagoda/8b6ac09e42d80632daee5e1e859e6000.jpg',
          'assets/images/pagodas/Shwezigon Pagoda/b24f40b7d21a7eace6ac017abfe2529c.jpg',
        ],
        historicalInfo: 'Construction began in 1059 under King Anawrahta, the founder of the Pagan Empire, and was completed by his son King Kyansittha in 1102. The pagoda was built to enshrine a replica of the Buddha\'s tooth relic from Sri Lanka and a frontal bone relic. It served as a model for many later Burmese stupas, including the Shwedagon Pagoda in Yangon. The pagoda has been restored several times, most notably after the 1975 earthquake.',
        architecturalStyle: 'Early Burmese Buddhist stupa architecture. Features a bell-shaped dome (anda) resting on three square terraces, surrounded by smaller stupas and shrines. The pagoda is gilded with gold leaf and stands 49 meters tall. It includes four shrines at the cardinal points, each containing a standing Buddha image, and is surrounded by a wall with glazed terracotta plaques.',
        yearBuilt: 1059,
      ),
      Pagoda(
        id: 'dhammayangyi',
        name: 'Dhammayangyi Temple',
        description: 'The largest of all the temples in Bagan, the Dhammayangyi Temple is a massive structure that dominates the Bagan skyline. Despite its impressive size, the temple remains shrouded in mystery and legend, with its interior corridors intentionally sealed. It represents one of the most ambitious construction projects of the Bagan period.',
        category: 'Temple',
        latitude: 21.161975,
        longitude: 94.872919,
        imageUrl: 'assets/images/pagodas/Dhammayangyi Temple/Dhammayangyi_Temple_at_Bagan,Myanmar.jpg',
        images: [
          'assets/images/pagodas/Dhammayangyi Temple/Dhammayangyi_Temple_at_Bagan,Myanmar.jpg',
          'assets/images/pagodas/Dhammayangyi Temple/4ab2ec43f3f2d08b50729cb10996ceb7.jpg',
          'assets/images/pagodas/Dhammayangyi Temple/68849e94e745de8b002956704ebeede9.jpg',
          'assets/images/pagodas/Dhammayangyi Temple/9e807d4da601404ff01e6790208424d5.jpg',
          'assets/images/pagodas/Dhammayangyi Temple/ecee1ff1c81b192055a305afbebfa8f5.jpg',
        ],
        historicalInfo: 'Built during the reign of King Narathu (1167-1170), who came to power after murdering his father and brother. According to legend, the king built this temple to atone for his sins, but the construction was never completed. The interior corridors were intentionally sealed, possibly to prevent access to the inner sanctum. King Narathu was assassinated before the temple\'s completion, and the structure has remained largely unchanged since. The temple\'s massive size and precise brickwork demonstrate advanced engineering skills of the period.',
        architecturalStyle: 'Massive Bagan period temple architecture. Features a square base measuring 78 meters on each side, with two inner ambulatories and a central cube. The temple stands approximately 60 meters tall. The brickwork is exceptionally precise, with joints so tight that not even a pin can be inserted. The structure includes four porches, but the interior corridors are sealed. The temple\'s design is similar to the Ananda Temple but on a much larger scale.',
        yearBuilt: 1170,
      ),
      Pagoda(
        id: 'thatbinnyu',
        name: 'Thatbyinnyu Temple',
        description: 'The tallest temple in Bagan, standing at 66 meters (217 feet), the Thatbyinnyu Temple is a magnificent structure that can be seen from miles away. Its name means "omniscience" in Pali, referring to the Buddha\'s all-knowing wisdom. The temple represents the transition from Mon to indigenous Bagan architectural styles.',
        category: 'Temple',
        latitude: 21.16875,
        longitude: 94.86295,
        imageUrl: 'assets/images/pagodas/Thatbyinnyu Temple/df0ebad94c9d9d41e52b1d2c74fdead2.jpg',
        images: [
          'assets/images/pagodas/Thatbyinnyu Temple/df0ebad94c9d9d41e52b1d2c74fdead2.jpg',
          'assets/images/pagodas/Thatbyinnyu Temple/04b3e46839edfdca218c2cce107f5587.jpg',
          'assets/images/pagodas/Thatbyinnyu Temple/1f1ce06e7352fa7895d920c25aa69217.jpg',
          'assets/images/pagodas/Thatbyinnyu Temple/73f2dda8c9b643491943b7770863113c.jpg',
          'assets/images/pagodas/Thatbyinnyu Temple/9983f9bab2e9725fbc8b30d3f10ffd5d.jpg',
          'assets/images/pagodas/Thatbyinnyu Temple/d0816c063dd938dfd4ac214916fb19d6.jpg',
        ],
        historicalInfo: 'Built in 1144 during the reign of King Alaungsithu, who ruled from 1113 to 1167. The temple was constructed to demonstrate the king\'s devotion and the kingdom\'s prosperity. It represents a significant architectural achievement, being the first temple to reach such height in Bagan. The temple has survived numerous earthquakes, though it suffered damage in the 1975 earthquake. Restoration work has been ongoing to preserve this important monument.',
        architecturalStyle: 'Early Bagan temple architecture with Mon influence. Features a two-story structure with a square base, four porches, and a tall superstructure. The temple has two levels of terraces, with the upper level containing the main shrine. The structure is built of brick and stucco, with the upper portions featuring intricate decorative elements. The temple\'s height and vertical emphasis represent a departure from earlier, more horizontal temple designs.',
        yearBuilt: 1144,
      ),
      Pagoda(
        id: 'htilominlo',
        name: 'Htilominlo Temple',
        description: 'A beautiful Buddhist temple in Bagan, built during the reign of King Htilominlo. The temple is renowned for its fine stucco carvings and glazed terracotta decorations. It represents the late Bagan period architecture and is one of the last major temples built before the decline of the Bagan Empire.',
        category: 'Temple',
        latitude: 21.178531,
        longitude: 94.879398,
        imageUrl: 'assets/images/pagodas/Htilominlo Temple/dee6e00eeb4074ee20f833988c05180f.jpg',
        images: [
          'assets/images/pagodas/Htilominlo Temple/dee6e00eeb4074ee20f833988c05180f.jpg',
          'assets/images/pagodas/Htilominlo Temple/0d1d7fa8c86705fdd1a404749b0d200c.jpg',
          'assets/images/pagodas/Htilominlo Temple/22e84597c74e80b981d1e58f5b33f339.jpg',
          'assets/images/pagodas/Htilominlo Temple/8f2f27db2e013baa142a74a15f67eac0.jpg',
          'assets/images/pagodas/Htilominlo Temple/bd1e3ba807c0ce68a65a7d1243778136.jpg',
        ],
        historicalInfo: 'Constructed in 1218 AD during the reign of King Htilominlo (also known as Nadaungmya), who ruled from 1211 to 1235. The temple was built to commemorate the king\'s selection as heir through a white umbrella test. The temple represents the late period of Bagan architecture, showing refined decorative techniques. It has been restored several times, most recently after earthquake damage. The temple remains an important example of late Bagan artistic achievement.',
        architecturalStyle: 'Late Bagan style temple architecture. Features a two-story structure with a square base, four porches, and intricate stucco decorations. The temple stands approximately 46 meters tall and includes fine examples of glazed terracotta plaques. The decorative elements are more elaborate than earlier temples, with detailed carvings on the exterior walls. The structure includes two levels of terraces and a central shrine housing Buddha images.',
        yearBuilt: 1218,
      ),
      Pagoda(
        id: 'alodawpyae',
        name: 'Alodawpyae Pagoda',
        description: 'A beautiful pagoda in Bagan known for its distinctive architecture and serene setting. The Alodawpyae Pagoda features a unique design that combines elements of both temple and stupa architecture. It is located in a peaceful area away from the main tourist routes, offering visitors a more intimate experience.',
        category: 'Pagoda',
        latitude: 21.176739,
        longitude: 94.882814,
        imageUrl: 'assets/images/pagodas/Alodawpyae Pagoda/Alodawpyi_Pagoda.jpg',
        images: [
          'assets/images/pagodas/Alodawpyae Pagoda/Alodawpyi_Pagoda.jpg',
        ],
        historicalInfo: 'Built during the Bagan period, around 1100 AD. The pagoda\'s name means "wish-fulfilling" in Burmese, reflecting its significance as a place of prayer and meditation. The structure has been maintained over the centuries and represents the diversity of architectural styles in Bagan. While less famous than the major temples, it remains an important part of Bagan\'s religious landscape.',
        architecturalStyle: 'Bagan period pagoda architecture with unique hybrid design. Features a bell-shaped stupa resting on a square base with decorative terraces. The pagoda combines elements of both temple and stupa architecture, with a central structure surrounded by smaller shrines. The design includes intricate brickwork and stucco decorations typical of the Bagan period.',
        yearBuilt: 1100,
      ),
      Pagoda(
        id: 'bupaya',
        name: 'Bu Paya',
        description: 'An ancient pagoda in Bagan with rich history, located on the banks of the Irrawaddy River. The Bu Paya (also known as Bupaya) is one of the oldest pagodas in Bagan and is famous for its distinctive bulbous, gourd-shaped design. It offers stunning views of the river and is particularly beautiful at sunset.',
        category: 'Pagoda',
        latitude: 21.1763128,
        longitude: 94.857903,
        imageUrl: 'assets/images/pagodas/BuPaya/Bupaya-Pagoda-and-Irrawaddy-in-the-back.jpg',
        images: [
          'assets/images/pagodas/BuPaya/Bupaya-Pagoda-and-Irrawaddy-in-the-back.jpg',
        ],
        historicalInfo: 'One of the oldest pagodas in Bagan, originally built around 850 AD during the early Bagan period. According to legend, the pagoda was built by King Pyusawhti, the third king of Bagan. The original structure was destroyed by the 1975 earthquake and was completely rebuilt in 1976-1977. The pagoda\'s name "Bu" means "gourd" in Burmese, referring to its distinctive shape. It has been an important landmark for river travelers for over a millennium.',
        architecturalStyle: 'Early Bagan style with unique gourd-shaped (bulbous) design. Features a distinctive bulbous stupa shape that is unique among Bagan pagodas. The pagoda is relatively small compared to later structures but is notable for its unusual form. The current structure is a reconstruction of the original, maintaining the traditional design while using modern materials for earthquake resistance.',
        yearBuilt: 850,
      ),
      Pagoda(
        id: 'dhammayazaka',
        name: 'Dhammayazaka',
        description: 'A significant temple in the Bagan archaeological zone, the Dhammayazaka (also spelled Dhammayazika) is notable for its pentagonal design, which is unique among Bagan temples. The temple features five Buddha images instead of the usual four, representing the five Buddhas of the current era.',
        category: 'Temple',
        latitude: 21.145071,
        longitude: 94.883451,
        imageUrl: 'assets/images/pagodas/Dhammayazaka/dhammayazika-pagoda-l.jpg',
        images: [
          'assets/images/pagodas/Dhammayazaka/dhammayazika-pagoda-l.jpg',
          'assets/images/pagodas/Dhammayazaka/0131c03dca6c301f2f042a32ab601c77.jpg',
          'assets/images/pagodas/Dhammayazaka/29283936522_b9a860e2bc_b.jpg',
          'assets/images/pagodas/Dhammayazaka/Dhamma-Yazaka.JPG',
        ],
        historicalInfo: 'Built during the golden age of Bagan, around 1196 AD, during the reign of King Narapatisithu. The temple\'s unique pentagonal design reflects esoteric Buddhist beliefs about the five Buddhas of the current era (Kakusandha, Konagamana, Kassapa, Gotama, and Metteyya). The temple represents a departure from the standard four-directional design of earlier temples. It has been restored and remains an active place of worship.',
        architecturalStyle: 'Unique pentagonal Bagan architecture. Features a pentagonal ground plan with five porches, each containing a seated Buddha image. The temple has a bell-shaped stupa resting on multiple terraces, surrounded by smaller stupas. The design is unique in Bagan, with no other temple featuring this pentagonal layout. The structure includes intricate stucco decorations and glazed terracotta plaques.',
        yearBuilt: 1196,
      ),
      Pagoda(
        id: 'gawdawpalin',
        name: 'Gawdawpalin Temple',
        description: 'A large and impressive temple complex in Bagan, the Gawdawpalin Temple is one of the largest and most imposing structures in the ancient city. The temple\'s name means "Platform to which Homage is Paid" and it represents the pinnacle of Bagan temple architecture before the decline of the empire.',
        category: 'Temple',
        latitude: 21.17,
        longitude: 94.856667,
        imageUrl: 'assets/images/pagodas/Gawdawpalin Temple/istockphoto-479621119-612x612.jpg',
        images: [
          'assets/images/pagodas/Gawdawpalin Temple/istockphoto-479621119-612x612.jpg',
          'assets/images/pagodas/Gawdawpalin Temple/31922c378893074a240e3f07913b4d18.jpg',
          'assets/images/pagodas/Gawdawpalin Temple/a1097ee0b3e8a893a5a5cda8d6abd179.jpg',
          'assets/images/pagodas/Gawdawpalin Temple/c99d79b76c44edea7f389650567fbc14.jpg',
          'assets/images/pagodas/Gawdawpalin Temple/unnamed.jpg',
        ],
        historicalInfo: 'Constructed in the late 12th century, around 1200 AD, during the reign of King Narapatisithu and completed by his son King Htilominlo. The temple was severely damaged in the 1975 earthquake, with the upper portion collapsing. It underwent extensive restoration work and was reopened in 1998. The temple represents one of the last major construction projects of the Bagan period and demonstrates the advanced engineering skills of the time.',
        architecturalStyle: 'Late Bagan period temple architecture. Features a massive two-story structure with a square base measuring approximately 60 meters on each side. The temple stands about 55 meters tall and includes two levels of terraces. The structure has four porches and contains multiple Buddha images. The architecture shows refined decorative techniques with intricate stucco work and glazed terracotta elements. The temple\'s scale and complexity represent the height of Bagan architectural achievement.',
        yearBuilt: 1200,
      ),
      Pagoda(
        id: 'gubyaukgyi',
        name: 'Gu Byauk Gyi Pagoda',
        description: 'A well-preserved pagoda in Bagan, the Gu Byauk Gyi (also spelled Gubyaukgyi) is famous for its beautiful frescoes and murals depicting Jataka tales. The pagoda is one of the best examples of Bagan period wall paintings and provides valuable insights into the artistic traditions of the time.',
        category: 'Pagoda',
        latitude: 21.157222,
        longitude: 94.860833,
        imageUrl: 'assets/images/pagodas/Gu Byauk Gyi Pagoda/gubyaukgyi-temple.jpg',
        images: [
          'assets/images/pagodas/Gu Byauk Gyi Pagoda/gubyaukgyi-temple.jpg',
          'assets/images/pagodas/Gu Byauk Gyi Pagoda/6b50c877-94fe-462b-a833-13e77977d711.jpg',
          'assets/images/pagodas/Gu Byauk Gyi Pagoda/Gubyaukgyi-Bagan-Myanmar-02-gje.jpg',
          'assets/images/pagodas/Gu Byauk Gyi Pagoda/gubyaukgyi-temple1.jpg',
          'assets/images/pagodas/Gu Byauk Gyi Pagoda/le-merite-de-ce-temple.jpg',
        ],
        historicalInfo: 'Built in 1113 AD during the reign of King Kyansittha. The pagoda was constructed by Prince Rajakumar, the son of King Kyansittha, to honor his father. The temple is renowned for its extensive wall paintings, which are among the best-preserved examples of Bagan period art. The frescoes depict scenes from the Jataka tales (stories of the Buddha\'s previous lives) and provide important historical and artistic documentation. The paintings have been carefully preserved and restored.',
        architecturalStyle: 'Bagan period pagoda architecture with Indian influence. Features a square base with a central shrine and a tall superstructure. The pagoda is notable for its extensive interior wall paintings, which cover most of the interior surfaces. The architecture includes elements of both Mon and Indian styles, with a focus on providing space for the elaborate murals. The structure has been carefully maintained to preserve the fragile paintings.',
        yearBuilt: 1113,
      ),
      Pagoda(
        id: 'izagawna',
        name: 'Iza Gawna Pagoda',
        description: 'A historic pagoda in the Bagan area, the Iza Gawna Pagoda (also known as Shin Izza Gawna) is a smaller but significant structure that represents the diversity of Bagan\'s religious architecture. The pagoda is known for its peaceful atmosphere and traditional design.',
        category: 'Pagoda',
        latitude: 21.17025,
        longitude: 94.90586,
        imageUrl: 'assets/images/pagodas/Iza Gawna Pagoda/normal_iza_gawna_pagoda__bagan.jpg',
        images: [
          'assets/images/pagodas/Iza Gawna Pagoda/normal_iza_gawna_pagoda__bagan.jpg',
          'assets/images/pagodas/Iza Gawna Pagoda/80iza-gawna-pagoda-bagan-thesanetravel.com-1610395.jpg',
          'assets/images/pagodas/Iza Gawna Pagoda/shin-izza-gawna-temple.jpg',
        ],
        historicalInfo: 'Part of Bagan\'s rich heritage, built around 1050 AD during the early Bagan period. The pagoda is associated with a monk named Shin Izza Gawna, after whom it is named. While less documented than the major temples, it represents the widespread religious construction that characterized the Bagan period. The pagoda has been maintained over the centuries and continues to serve as a place of worship.',
        architecturalStyle: 'Early Bagan architecture with traditional pagoda design. Features a bell-shaped stupa resting on multiple terraces, typical of early Bagan pagodas. The structure is smaller than the major temples but follows traditional design principles. The pagoda includes decorative elements and is surrounded by smaller shrines, creating a complete religious complex.',
        yearBuilt: 1050,
      ),
      Pagoda(
        id: 'lawkananda',
        name: 'Lawkananda Pagoda',
        description: 'A prominent pagoda in Bagan, the Lawkananda Pagoda is located on the banks of the Irrawaddy River and is famous for its beautiful riverside setting. The pagoda is particularly popular for sunset viewing and offers panoramic views of the river and surrounding countryside.',
        category: 'Pagoda',
        latitude: 21.127222,
        longitude: 94.850556,
        imageUrl: 'assets/images/pagodas/Lawkananda Pagoda/20102959715_e7e032d5af_b.jpg',
        images: [
          'assets/images/pagodas/Lawkananda Pagoda/20102959715_e7e032d5af_b.jpg',
          'assets/images/pagodas/Lawkananda Pagoda/302dde16fdd87aabd4a91c5033cfc7d5.jpg',
          'assets/images/pagodas/Lawkananda Pagoda/dbae0ac1f0ec53e986ca8770610630f7.jpg',
        ],
        historicalInfo: 'Built during the Bagan dynasty, around 1070 AD, during the reign of King Anawrahta. The pagoda was constructed to enshrine a replica of the Buddha\'s tooth relic. According to legend, the pagoda marks the spot where a sacred relic was received from Sri Lanka. The pagoda\'s riverside location made it an important landmark for river travelers and traders. It has been restored several times and remains an active place of worship.',
        architecturalStyle: 'Early Bagan pagoda architecture. Features a bell-shaped stupa with a distinctive elongated design, resting on multiple terraces. The pagoda is gilded and stands prominently on the riverbank. The structure includes decorative elements typical of early Bagan architecture, with stucco decorations and traditional Burmese design elements. The pagoda\'s location and design make it a prominent landmark.',
        yearBuilt: 1070,
      ),
      Pagoda(
        id: 'mahazedi',
        name: 'Mahazedi Pagoda',
        description: 'A large and impressive stupa in Bagan, the Mahezedi Pagoda (also spelled Mahazedi) is known for its size and historical significance. The pagoda represents the later period of Bagan construction and demonstrates the continued importance of religious building even as the empire began to decline.',
        category: 'Pagoda',
        latitude: 21.1645,
        longitude: 94.86229,
        imageUrl: 'assets/images/pagodas/Mahezedi Pagoda/Mahazedi_Pagoda_(Bagan).jpg',
        images: [
          'assets/images/pagodas/Mahezedi Pagoda/Mahazedi_Pagoda_(Bagan).jpg',
        ],
        historicalInfo: 'Constructed in the 13th century, around 1230 AD, during the later period of the Bagan Empire. The pagoda was built during a time when the empire was facing challenges, but religious construction continued. The structure has been restored over the centuries and represents the persistence of Bagan\'s religious traditions. The pagoda\'s name "Mahezedi" means "Great Stupa" in Pali, reflecting its significance.',
        architecturalStyle: 'Late Bagan period stupa architecture. Features a large bell-shaped stupa resting on multiple square terraces. The pagoda follows traditional Burmese stupa design but on a grand scale. The structure includes decorative elements and is surrounded by smaller shrines. The architecture demonstrates the continued refinement of stupa design in the later Bagan period.',
        yearBuilt: 1230,
      ),
      Pagoda(
        id: 'manuha',
        name: 'Manuha Temple',
        description: 'A temple built by King Manuha, the Manuha Temple tells a poignant story of captivity and devotion. The temple contains three large Buddha images that appear cramped within their chambers, symbolizing the king\'s feelings of confinement after being captured by King Anawrahta. It is one of the most emotionally powerful temples in Bagan.',
        category: 'Temple',
        latitude: 21.153408,
        longitude: 94.859152,
        imageUrl: 'assets/images/pagodas/Manuha/Manuha-Paya-1.jpg',
        images: [
          'assets/images/pagodas/Manuha/Manuha-Paya-1.jpg',
          'assets/images/pagodas/Manuha/67397682-manuha-temple-bagan-myanmar.jpg',
          'assets/images/pagodas/Manuha/Manuha-Temple-2.jpg',
        ],
        historicalInfo: 'Built by King Manuha in 1059 AD, after he was captured by King Anawrahta and brought to Bagan as a prisoner. King Manuha was the last king of the Mon kingdom of Thaton. According to legend, the king used his remaining gold to build this temple, and the cramped Buddha images represent his feelings of confinement and longing for freedom. The temple is a powerful symbol of the human cost of war and conquest. Despite his captivity, King Manuha\'s devotion to Buddhism is evident in the temple\'s construction.',
        architecturalStyle: 'Mon architecture with symbolic design elements. Features a rectangular structure containing three large Buddha images - two seated and one reclining - that appear too large for their chambers, creating a sense of confinement. The temple\'s design is intentionally symbolic, with the cramped space representing the builder\'s emotional state. The architecture combines Mon and early Bagan elements, creating a unique and emotionally resonant structure.',
        yearBuilt: 1059,
      ),
      Pagoda(
        id: 'pyathetgyi',
        name: 'Pyathetgyi Temple',
        description: 'A temple with unique architecture, the Pyathetgyi Temple (also known as Pyathatgyi or Pyathadar) is notable for its distinctive design and location. The temple features an open structure that is different from the enclosed designs of most Bagan temples, offering unobstructed views and a sense of openness.',
        category: 'Temple',
        latitude: 21.15829,
        longitude: 94.88957,
        imageUrl: 'assets/images/pagodas/Pyathetgyi/Pyathadar-Pyathatgyi-Temple.jpg',
        images: [
          'assets/images/pagodas/Pyathetgyi/Pyathadar-Pyathatgyi-Temple.jpg',
          'assets/images/pagodas/Pyathetgyi/19143645858_a8d4458a88_z.jpg',
          'assets/images/pagodas/Pyathetgyi/2244810100_e0d8d158d5_b.jpg',
          'assets/images/pagodas/Pyathetgyi/images.jpg',
          'assets/images/pagodas/Pyathetgyi/payahtaung-temple_BIG.jpg',
        ],
        historicalInfo: 'Built in the 13th century, around 1280 AD, during the final years of the Bagan Empire. The temple represents one of the last major construction projects before the Mongol invasions and the decline of Bagan. The temple\'s open design is unique among Bagan structures and may reflect changing architectural preferences or practical considerations. Despite being built during a period of decline, the temple demonstrates continued artistic achievement.',
        architecturalStyle: 'Late Bagan architecture with unique open design. Features a square base with an open structure, lacking the enclosed corridors typical of earlier temples. The temple has multiple terraces and a central shrine, but the design emphasizes openness and views rather than enclosed spaces. The architecture represents a departure from traditional Bagan temple design, possibly reflecting the influence of different architectural traditions or changing religious practices.',
        yearBuilt: 1280,
      ),
      Pagoda(
        id: 'seinnyetnyiama',
        name: 'Sein Nyet Nyi Ama Gu Phaya',
        description: 'A pagoda with beautiful surroundings, the Sein Nyet Nyi Ama Gu Phaya (also known as Seinnyet Nyima and Seinnyet Ama) consists of two structures - a pagoda and a temple - built side by side. The complex represents a unique architectural arrangement in Bagan and is known for its harmonious design and peaceful setting.',
        category: 'Pagoda',
        latitude: 21.14151,
        longitude: 94.85896,
        imageUrl: 'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/Seinnyet-Nyima-Seinnyet-Ama-Paya-Bagan-Myanmar.jpg',
        images: [
          'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/Seinnyet-Nyima-Seinnyet-Ama-Paya-Bagan-Myanmar.jpg',
          'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/69sein-nyet-temple-bagan-thesanetravel.com-1610978.jpg',
          'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/sein-nyet-ama01.jpg',
          'assets/images/pagodas/Sein Nyet NyiAma Gu Phaya/seinnyet-ama-temple-Bagan-Myanmar.jpg',
        ],
        historicalInfo: 'Part of Bagan\'s temple complex, built around 1100 AD during the middle period of the Bagan Empire. The complex consists of two structures built together - a pagoda (Seinnyet Nyima) and a temple (Seinnyet Ama) - representing a unique architectural arrangement. The name "Sein Nyet" means "sister" in Burmese, and the two structures are said to represent two sisters. The complex has been maintained over the centuries and represents the diversity of Bagan\'s religious architecture.',
        architecturalStyle: 'Bagan period architecture with unique dual-structure design. Features two structures built side by side - a bell-shaped pagoda and a square temple - creating a harmonious architectural composition. The pagoda follows traditional Bagan stupa design, while the temple features a square base with a central shrine. The two structures complement each other architecturally and create a unique visual effect. The complex demonstrates the flexibility and creativity of Bagan architects.',
        yearBuilt: 1100,
      ),
      Pagoda(
        id: 'shwegugyi',
        name: 'Shwe Gu Gyi',
        description: 'A golden pagoda in Bagan, the Shwe Gu Gyi (also spelled Shwegugyi) is known for its beautiful golden appearance and elegant design. The pagoda\'s name means "Great Golden Cave" and it is one of the most photogenic structures in Bagan, particularly beautiful in the golden light of sunrise and sunset.',
        category: 'Pagoda',
        latitude: 21.170744,
        longitude: 94.862406,
        imageUrl: 'assets/images/pagodas/Shwe Gu Gyi/Shwegugyi-Temple-1-600x400.jpg',
        images: [
          'assets/images/pagodas/Shwe Gu Gyi/Shwegugyi-Temple-1-600x400.jpg',
          'assets/images/pagodas/Shwe Gu Gyi/Shwegugyi-Temple-2-600x400.jpg',
          'assets/images/pagodas/Shwe Gu Gyi/4.jpg',
          'assets/images/pagodas/Shwe Gu Gyi/White_Temple_(8404485009).jpg',
        ],
        historicalInfo: 'Known for its golden appearance, built around 1150 AD during the middle period of the Bagan Empire. The pagoda\'s golden exterior makes it stand out among Bagan\'s many structures. The temple has been maintained and regilded over the centuries, maintaining its distinctive appearance. While less documented than the major temples, it represents the widespread religious construction that characterized Bagan and demonstrates the importance of visual beauty in religious architecture.',
        architecturalStyle: 'Bagan period pagoda architecture with golden decoration. Features a traditional bell-shaped stupa design with a golden exterior that creates a striking visual effect. The pagoda follows classic Bagan architectural principles but is distinguished by its golden appearance. The structure includes decorative elements and is surrounded by smaller shrines. The golden decoration reflects the importance of visual splendor in Buddhist religious architecture.',
        yearBuilt: 1150,
      ),
      Pagoda(
        id: 'sulamani',
        name: 'Sulamani Temple',
        description: 'One of the most beautiful temples in Bagan, the Sulamani Temple is renowned for its fine brickwork, intricate stucco carvings, and beautiful frescoes. The temple\'s name means "Crowning Jewel" or "Small Ruby" and it truly lives up to its name as one of the architectural gems of Bagan.',
        category: 'Temple',
        latitude: 21.1649,
        longitude: 94.8814,
        imageUrl: 'assets/images/pagodas/Sulamani Temple/sulamani-temple-bagan-myanmar-sunset-asia-82328684.webp',
        images: [
          'assets/images/pagodas/Sulamani Temple/sulamani-temple-bagan-myanmar-sunset-asia-82328684.webp',
          'assets/images/pagodas/Sulamani Temple/7e5692c46b129496fc9c5a5e966b4621.jpg',
          'assets/images/pagodas/Sulamani Temple/f8c78d47d5b874f6e2791396bdc5d436.jpg',
          'assets/images/pagodas/Sulamani Temple/late-afternoon-sun-shines-on-260nw-406636576.webp',
        ],
        historicalInfo: 'Built in 1183 AD during the reign of King Narapatisithu, who ruled from 1174 to 1211. The temple was constructed as a royal temple and represents one of the finest examples of Bagan architecture. The temple\'s name "Sulamani" means "Crowning Jewel" in Pali, reflecting its importance and beauty. The temple has survived numerous earthquakes and has been carefully restored. It contains some of the best-preserved frescoes in Bagan, depicting scenes from the Jataka tales and the life of the Buddha.',
        architecturalStyle: 'Late Bagan period temple architecture with refined decorative techniques. Features a two-story structure with a square base, four porches, and intricate stucco carvings. The temple stands approximately 50 meters tall and includes two levels of terraces. The architecture is notable for its fine brickwork and elaborate decorative elements, including glazed terracotta plaques and stucco carvings. The interior contains beautiful frescoes that are among the best-preserved examples of Bagan period art. The temple represents the height of artistic achievement in late Bagan architecture.',
        yearBuilt: 1183,
      ),
      Pagoda(
        id: 'thambula',
        name: 'Thambula Temple',
        description: 'A temple with intricate carvings, the Thambula Temple is known for its beautiful decorative elements and fine architectural details. The temple represents the artistic refinement of the Bagan period and demonstrates the skill of Bagan craftsmen in creating detailed decorative work.',
        category: 'Temple',
        latitude: 21.162594,
        longitude: 94.903672,
        imageUrl: 'assets/images/pagodas/Thambula/thambula-temple.jpg',
        images: [
          'assets/images/pagodas/Thambula/thambula-temple.jpg',
          'assets/images/pagodas/Thambula/istockphoto-180775378-612x612.jpg',
          'assets/images/pagodas/Thambula/istockphoto-486732962-612x612.jpg',
          'assets/images/pagodas/Thambula/istockphoto-90658155-612x612.jpg',
        ],
        historicalInfo: 'Built in the 13th century, around 1255 AD, during the later period of the Bagan Empire. The temple was constructed during a time when the empire was facing challenges, but artistic achievement continued. The temple is named after Queen Thambula, who may have sponsored its construction. Despite being built during a period of decline, the temple demonstrates continued artistic excellence and attention to detail. The temple has been restored and remains an important example of late Bagan architecture.',
        architecturalStyle: 'Late Bagan period temple architecture with emphasis on decorative elements. Features a square base with a central shrine and intricate stucco carvings throughout. The temple is notable for its detailed decorative work, including carved reliefs and ornamental elements. The architecture follows traditional Bagan design principles but with particular attention to decorative detail. The temple\'s carvings demonstrate the continued refinement of artistic techniques in the later Bagan period.',
        yearBuilt: 1255,
      ),
    ];

    for (var pagoda in samplePagodas) {
      await _db.insertPagoda(pagoda);
    }
  }
}
