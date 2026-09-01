import 'package:baganetic_mobile/data/models/travel_place.dart';
import 'package:baganetic_mobile/data/services/travel_place_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled travel catalogue has sourced entries for every category', () async {
    final places = await const TravelPlaceDataService().loadPlaces();

    expect(places, hasLength(10));
    expect(places.map((place) => place.id).toSet(), hasLength(places.length));
    expect(
      places.where((place) => place.category == TravelPlaceCategory.stay),
      hasLength(3),
    );
    expect(
      places.where((place) => place.category == TravelPlaceCategory.food),
      hasLength(3),
    );
    expect(
      places.where((place) => place.category == TravelPlaceCategory.transport),
      hasLength(4),
    );
    for (final place in places) {
      expect(place.sourceUrl, startsWith('https://'));
      expect(place.latitude, inInclusiveRange(-90, 90));
      expect(place.longitude, inInclusiveRange(-180, 180));
      expect(place.lastVerified, DateTime(2026, 9, 1));
    }
  });
}
