import 'package:baganetic_mobile/data/models/pagoda_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> pagodaJson({
  required String id,
  bool? isHomeFeatured,
  int? homeFeaturedOrder,
}) => {
  'id': id,
  'name': 'Example Pagoda',
  'description': 'Example description',
  'category': 'Pagoda',
  'latitude': 21.17,
  'longitude': 94.86,
  'imageUrl': 'assets/images/pagodas/example.jpg',
  if (isHomeFeatured != null) 'isHomeFeatured': isHomeFeatured,
  if (homeFeaturedOrder != null) 'homeFeaturedOrder': homeFeaturedOrder,
};

void main() {
  test('keeps the existing two popular pagodas featured for legacy records', () {
    final ananda = Pagoda.fromJson(pagodaJson(id: 'ananda'));
    final shwesandaw = Pagoda.fromJson(pagodaJson(id: 'shwesandaw'));

    expect(ananda.isHomeFeatured, isTrue);
    expect(ananda.homeFeaturedOrder, 1);
    expect(shwesandaw.isHomeFeatured, isTrue);
    expect(shwesandaw.homeFeaturedOrder, 2);
  });

  test('uses the featured settings saved by the admin', () {
    final pagoda = Pagoda.fromJson(
      pagodaJson(
        id: 'ananda',
        isHomeFeatured: false,
        homeFeaturedOrder: 7,
      ),
    );

    expect(pagoda.isHomeFeatured, isFalse);
    expect(pagoda.homeFeaturedOrder, 7);
  });
}
