import '../../data/models/discovery_item.dart';

class DiscoverySearchService {
  List<DiscoveryItem> filterItems({
    required List<DiscoveryItem> items,
    required String selectedCategory,
    required String searchQuery,
  }) {
    var filtered = List<DiscoveryItem>.from(items);

    if (selectedCategory != 'All') {
      filtered = filtered
          .where((item) => item.type == selectedCategory)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.address.toLowerCase().contains(query) ||
            item.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    filtered.sort((a, b) {
      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) return ratingCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }
}
