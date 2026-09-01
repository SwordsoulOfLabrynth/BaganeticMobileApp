import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/travel_place.dart';

/// Loads the small, curated travel catalogue bundled with the app so it is
/// available even when the visitor has no connection in Bagan.
class TravelPlaceDataService {
  const TravelPlaceDataService();

  static const _assetPath = 'assets/data/bagan_travel_places.json';

  Future<List<TravelPlace>> loadPlaces() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final jsonData = jsonDecode(jsonString) as List<dynamic>;
    return jsonData
        .map((item) => TravelPlace.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
