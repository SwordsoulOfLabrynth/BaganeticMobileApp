enum TravelPlaceCategory { stay, food, transport }

TravelPlaceCategory _categoryFromJson(String rawCategory) {
  return switch (rawCategory) {
    'stay' => TravelPlaceCategory.stay,
    'food' => TravelPlaceCategory.food,
    'transport' => TravelPlaceCategory.transport,
    _ => throw FormatException('Unsupported travel place category: $rawCategory'),
  };
}

class TravelPlace {
  const TravelPlace({
    required this.id,
    required this.name,
    required this.nameMyanmar,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.summary,
    required this.summaryMyanmar,
    required this.note,
    required this.noteMyanmar,
    required this.sourceName,
    required this.sourceUrl,
    required this.lastVerified,
  });

  final String id;
  final String name;
  final String nameMyanmar;
  final TravelPlaceCategory category;
  final double latitude;
  final double longitude;
  final String area;
  final String summary;
  final String summaryMyanmar;
  final String note;
  final String noteMyanmar;
  final String sourceName;
  final String sourceUrl;
  final DateTime lastVerified;

  factory TravelPlace.fromJson(Map<String, dynamic> json) {
    return TravelPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String? ?? json['name'] as String,
      category: _categoryFromJson(json['category'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      area: json['area'] as String,
      summary: json['summary'] as String,
      summaryMyanmar: json['summaryMyanmar'] as String? ?? json['summary'] as String,
      note: json['note'] as String,
      noteMyanmar: json['noteMyanmar'] as String? ?? json['note'] as String,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      lastVerified: DateTime.parse(json['lastVerified'] as String),
    );
  }
}
