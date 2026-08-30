import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';

/// Approximate Bagan archaeological-zone box used for tile prefetch and GPS hints.
class BaganMapCoverage {
  const BaganMapCoverage._();

  static bool contains(LatLng point) {
    final south =
        AppConstants.baganLatitude - AppConstants.mapCoverageLatitudePadding;
    final north =
        AppConstants.baganLatitude + AppConstants.mapCoverageLatitudePadding;
    final west =
        AppConstants.baganLongitude - AppConstants.mapCoverageLongitudePadding;
    final east =
        AppConstants.baganLongitude + AppConstants.mapCoverageLongitudePadding;
    return point.latitude >= south &&
        point.latitude <= north &&
        point.longitude >= west &&
        point.longitude <= east;
  }
}
