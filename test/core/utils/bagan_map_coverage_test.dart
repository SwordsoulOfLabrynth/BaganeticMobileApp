import 'package:baganetic_mobile/core/utils/bagan_map_coverage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Old Bagan is inside the cached map coverage box', () {
    expect(
      BaganMapCoverage.contains(const LatLng(21.1717, 94.8589)),
      isTrue,
    );
    expect(
      BaganMapCoverage.contains(const LatLng(21.1708, 94.8679)),
      isTrue,
    );
  });

  test('Yangon is outside the cached Bagan map coverage box', () {
    expect(
      BaganMapCoverage.contains(const LatLng(16.8409, 96.1735)),
      isFalse,
    );
  });
}
