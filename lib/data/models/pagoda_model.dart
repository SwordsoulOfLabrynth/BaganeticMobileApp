import '../../core/utils/image_path_utils.dart';

class Pagoda {
  final String id;
  final String name;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final List<String> images;
  final String? historicalInfo;
  final String? architecturalStyle;
  final int? yearBuilt;
  final bool isFavorite;
  
  Pagoda({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    this.images = const [],
    this.historicalInfo,
    this.architecturalStyle,
    this.yearBuilt,
    this.isFavorite = false,
  });
  
  factory Pagoda.fromJson(Map<String, dynamic> json) {
    // Normalize image paths
    final String? imageUrlRaw = json['imageUrl'] as String?;
    final String normalizedImageUrl = imageUrlRaw != null 
        ? ImagePathUtils.normalizeImagePath(imageUrlRaw)
        : '';
    
    final List<String> normalizedImages = (json['images'] as List<dynamic>?)
            ?.map((e) => ImagePathUtils.normalizeImagePath(e as String))
            .where((path) => path.isNotEmpty)
            .toList() ?? [];
    
    return Pagoda(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'Temple',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: normalizedImageUrl,
      images: normalizedImages,
      historicalInfo: json['historicalInfo'] as String?,
      architecturalStyle: json['architecturalStyle'] as String?,
      yearBuilt: json['yearBuilt'] as int?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'images': images,
      'historicalInfo': historicalInfo,
      'architecturalStyle': architecturalStyle,
      'yearBuilt': yearBuilt,
      'isFavorite': isFavorite,
    };
  }
  
  Pagoda copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? images,
    String? historicalInfo,
    String? architecturalStyle,
    int? yearBuilt,
    bool? isFavorite,
  }) {
    return Pagoda(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      historicalInfo: historicalInfo ?? this.historicalInfo,
      architecturalStyle: architecturalStyle ?? this.architecturalStyle,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
