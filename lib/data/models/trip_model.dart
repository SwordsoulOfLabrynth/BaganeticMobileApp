enum TripTransportMode {
  walk('walk', 5),
  bike('bike', 15),
  car('car', 30);

  const TripTransportMode(this.storageValue, this.averageSpeedKph);

  final String storageValue;
  final double averageSpeedKph;

  static TripTransportMode fromStorage(String? value) {
    return TripTransportMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => TripTransportMode.walk,
    );
  }
}

class Trip {
  final String id;
  final String ownerUserId;
  final String name;
  final String? description;
  final TripTransportMode transportMode;
  final DateTime date;
  final List<TripStop> stops;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.ownerUserId,
    required this.name,
    this.description,
    required this.transportMode,
    required this.date,
    required this.stops,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      transportMode: TripTransportMode.fromStorage(
        json['transportMode'] as String?,
      ),
      date: DateTime.parse(json['date'] as String),
      stops: (json['stops'] as List<dynamic>)
          .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'name': name,
      'description': description,
      'transportMode': transportMode.storageValue,
      'date': date.toIso8601String(),
      'stops': stops.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Trip copyWith({
    String? id,
    String? ownerUserId,
    String? name,
    String? description,
    TripTransportMode? transportMode,
    DateTime? date,
    List<TripStop>? stops,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      description: description ?? this.description,
      transportMode: transportMode ?? this.transportMode,
      date: date ?? this.date,
      stops: stops ?? this.stops,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double getTotalDistance() {
    if (stops.length < 2) return 0;
    return stops.fold(0.0, (sum, stop) => sum + (stop.distanceToNext ?? 0));
  }

  int getEstimatedTravelDuration() {
    if (stops.length < 2) return 0;
    final travelTime = getTotalDistance() / transportMode.averageSpeedKph * 60;
    return travelTime.round();
  }
}

class TripStop {
  final String pagodaId;
  final String pagodaName;
  final double latitude;
  final double longitude;
  final int order;
  final String? notes;
  final double? distanceToNext;

  TripStop({
    required this.pagodaId,
    required this.pagodaName,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.notes,
    this.distanceToNext,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      pagodaId: json['pagodaId'] as String,
      pagodaName: json['pagodaName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      order: json['order'] as int,
      notes: json['notes'] as String?,
      distanceToNext: (json['distanceToNext'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pagodaId': pagodaId,
      'pagodaName': pagodaName,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'notes': notes,
      'distanceToNext': distanceToNext,
    };
  }
}
