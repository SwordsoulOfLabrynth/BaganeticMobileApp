import '../../core/utils/image_path_utils.dart';

String _normalizePagodaCategory(String? rawCategory) {
  if (rawCategory == 'Temple') {
    return 'Temple';
  }
  return 'Pagoda';
}

bool _readBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return fallback;
}

int? _readNullableInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _legacyHomeFeaturedDefault(String id) =>
    id == 'ananda' || id == 'shwesandaw';

int _legacyHomeFeaturedOrder(String id) => switch (id) {
  'ananda' => 1,
  'shwesandaw' => 2,
  _ => 0,
};

class PagodaFeature {
  final String title;
  final String description;
  final String? icon;
  final String? imageUrl;

  const PagodaFeature({
    required this.title,
    required this.description,
    this.icon,
    this.imageUrl,
  });

  factory PagodaFeature.fromJson(Map<String, dynamic> json) {
    return PagodaFeature(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'imageUrl': imageUrl,
    };
  }
}

class Pagoda {
  final String id;
  final String name;
  final String? nameMyanmar;
  final String description;
  final String? descriptionMyanmar;
  final String category;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final List<String> images;
  final String? historicalInfo;
  final String? architecturalStyle;
  final int? yearBuilt;
  final bool isFavorite;
  /// Whether this pagoda appears in the Popular Pagodas section on Home.
  final bool isHomeFeatured;
  /// Lower values appear first when multiple pagodas are featured on Home.
  final int homeFeaturedOrder;

  // Enhanced fields from legacy web version
  final String? legends;
  final String? religiousImportance;
  final String? preservationInfo;
  final String? bestTimeToVisit;
  final String? visitorLocation;
  final String? openingHours;
  final String? dressCode;
  final String? entranceFee;
  final String? photographyRules;
  final String? height;
  final String? finalWords;
  final List<PagodaFeature> uniqueFeatures;

  Pagoda({
    required this.id,
    required this.name,
    this.nameMyanmar,
    required this.description,
    this.descriptionMyanmar,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    this.images = const [],
    this.historicalInfo,
    this.architecturalStyle,
    this.yearBuilt,
    this.isFavorite = false,
    this.isHomeFeatured = false,
    this.homeFeaturedOrder = 0,
    // Enhanced fields
    this.legends,
    this.religiousImportance,
    this.preservationInfo,
    this.bestTimeToVisit,
    this.visitorLocation,
    this.openingHours,
    this.dressCode,
    this.entranceFee,
    this.photographyRules,
    this.height,
    this.finalWords,
    this.uniqueFeatures = const [],
  });

  factory Pagoda.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    // Normalize image paths
    final String? imageUrlRaw = json['imageUrl'] as String?;
    final String normalizedImageUrl = imageUrlRaw != null
        ? ImagePathUtils.normalizeImagePath(imageUrlRaw)
        : '';

    final List<String> normalizedImages =
        (json['images'] as List<dynamic>?)
            ?.map((e) => ImagePathUtils.normalizeImagePath(e as String))
            .where((path) => path.isNotEmpty)
            .toList() ??
        [];

    final List<PagodaFeature> features =
        (json['uniqueFeatures'] as List<dynamic>?)
            ?.map((e) => PagodaFeature.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Pagoda(
      id: id,
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String?,
      description: json['description'] as String,
      descriptionMyanmar: json['descriptionMyanmar'] as String?,
      category: _normalizePagodaCategory(json['category'] as String?),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: normalizedImageUrl,
      images: normalizedImages,
      historicalInfo: json['historicalInfo'] as String?,
      architecturalStyle: json['architecturalStyle'] as String?,
      yearBuilt: (json['yearBuilt'] as num?)?.toInt(),
      isFavorite: _readBool(json['isFavorite'], fallback: false),
      // Keep the original two Home cards visible for legacy catalog records
      // until an admin explicitly saves their featured state.
      isHomeFeatured: _readBool(
        json['isHomeFeatured'],
        fallback: _legacyHomeFeaturedDefault(id),
      ),
      homeFeaturedOrder:
          _readNullableInt(json['homeFeaturedOrder']) ??
          _legacyHomeFeaturedOrder(id),
      // Enhanced fields
      legends: json['legends'] as String?,
      religiousImportance: json['religiousImportance'] as String?,
      preservationInfo: json['preservationInfo'] as String?,
      bestTimeToVisit: json['bestTimeToVisit'] as String?,
      visitorLocation: json['visitorLocation'] as String?,
      openingHours: json['openingHours'] as String?,
      dressCode: json['dressCode'] as String?,
      entranceFee: json['entranceFee'] as String?,
      photographyRules: json['photographyRules'] as String?,
      height: json['height'] as String?,
      finalWords: json['finalWords'] as String?,
      uniqueFeatures: features,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameMyanmar': nameMyanmar,
      'description': description,
      'descriptionMyanmar': descriptionMyanmar,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'images': images,
      'historicalInfo': historicalInfo,
      'architecturalStyle': architecturalStyle,
      'yearBuilt': yearBuilt,
      'isFavorite': isFavorite,
      'isHomeFeatured': isHomeFeatured,
      'homeFeaturedOrder': homeFeaturedOrder,
      // Enhanced fields
      'legends': legends,
      'religiousImportance': religiousImportance,
      'preservationInfo': preservationInfo,
      'bestTimeToVisit': bestTimeToVisit,
      'visitorLocation': visitorLocation,
      'openingHours': openingHours,
      'dressCode': dressCode,
      'entranceFee': entranceFee,
      'photographyRules': photographyRules,
      'height': height,
      'finalWords': finalWords,
      'uniqueFeatures': uniqueFeatures
          .map((feature) => feature.toJson())
          .toList(),
    };
  }

  Pagoda copyWith({
    String? id,
    String? name,
    String? nameMyanmar,
    String? description,
    String? descriptionMyanmar,
    String? category,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? images,
    String? historicalInfo,
    String? architecturalStyle,
    int? yearBuilt,
    bool? isFavorite,
    bool? isHomeFeatured,
    int? homeFeaturedOrder,
    // Enhanced fields
    String? legends,
    String? religiousImportance,
    String? preservationInfo,
    String? bestTimeToVisit,
    String? visitorLocation,
    String? openingHours,
    String? dressCode,
    String? entranceFee,
    String? photographyRules,
    String? height,
    String? finalWords,
    List<PagodaFeature>? uniqueFeatures,
  }) {
    return Pagoda(
      id: id ?? this.id,
      name: name ?? this.name,
      nameMyanmar: nameMyanmar ?? this.nameMyanmar,
      description: description ?? this.description,
      descriptionMyanmar: descriptionMyanmar ?? this.descriptionMyanmar,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      historicalInfo: historicalInfo ?? this.historicalInfo,
      architecturalStyle: architecturalStyle ?? this.architecturalStyle,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      isFavorite: isFavorite ?? this.isFavorite,
      isHomeFeatured: isHomeFeatured ?? this.isHomeFeatured,
      homeFeaturedOrder: homeFeaturedOrder ?? this.homeFeaturedOrder,
      // Enhanced fields
      legends: legends ?? this.legends,
      religiousImportance: religiousImportance ?? this.religiousImportance,
      preservationInfo: preservationInfo ?? this.preservationInfo,
      bestTimeToVisit: bestTimeToVisit ?? this.bestTimeToVisit,
      visitorLocation: visitorLocation ?? this.visitorLocation,
      openingHours: openingHours ?? this.openingHours,
      dressCode: dressCode ?? this.dressCode,
      entranceFee: entranceFee ?? this.entranceFee,
      photographyRules: photographyRules ?? this.photographyRules,
      height: height ?? this.height,
      finalWords: finalWords ?? this.finalWords,
      uniqueFeatures: uniqueFeatures ?? this.uniqueFeatures,
    );
  }
}
