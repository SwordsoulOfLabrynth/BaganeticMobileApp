class Trip {
  final String id;
  final String name;
  final String? description;
  final DateTime date;
  final List<TripStop> stops;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Trip({
    required this.id,
    required this.name,
    this.description,
    required this.date,
    required this.stops,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
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
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'stops': stops.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  double getTotalDistance() {
    if (stops.length < 2) return 0;
    return stops.fold(0.0, (sum, stop) => sum + (stop.distanceToNext ?? 0));
  }
  
  int getEstimatedDuration() {
    // Estimate 30 minutes per stop + travel time (5 km/h walking)
    double travelTime = getTotalDistance() / 5 * 60; // minutes
    double stopTime = stops.length * 30.0;
    return (travelTime + stopTime).round();
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
