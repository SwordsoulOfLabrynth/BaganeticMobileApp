class DiscoveryItem {
  final String id;
  final String name;
  final String type;
  final String description;
  final String address;
  final double rating;
  final String priceRange;
  final String openHours;
  final String phone;
  final List<String> tags;

  const DiscoveryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.address,
    required this.rating,
    required this.priceRange,
    required this.openHours,
    required this.phone,
    required this.tags,
  });

  bool get isHotel => type.toLowerCase() == 'hotel';

  factory DiscoveryItem.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((tag) => tag.toString()).toList()
        : const <String>[];
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0;

    return DiscoveryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Hotel',
      description: json['description']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      rating: rating,
      priceRange: json['priceRange']?.toString() ?? '',
      openHours: json['openHours']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'address': address,
      'rating': rating,
      'priceRange': priceRange,
      'openHours': openHours,
      'phone': phone,
      'tags': tags,
    };
  }
}
