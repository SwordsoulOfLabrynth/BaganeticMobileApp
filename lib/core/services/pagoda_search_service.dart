import '../../data/models/pagoda_model.dart';

class PagodaSearchService {
  List<Pagoda> filterPagodas({
    required List<Pagoda> pagodas,
    required String selectedCategory,
    required String searchQuery,
  }) {
    var filtered = List<Pagoda>.from(pagodas);

    if (selectedCategory != 'All') {
      filtered = filtered
          .where((pagoda) => pagoda.category == selectedCategory)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((pagoda) {
        return pagoda.name.toLowerCase().contains(query);
      }).toList();
    }

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }
}
