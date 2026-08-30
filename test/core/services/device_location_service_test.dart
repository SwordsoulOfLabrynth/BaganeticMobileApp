import 'package:baganetic_mobile/core/services/device_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _position(double latitude, double longitude) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime.utc(2026, 8, 29),
    accuracy: 6,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  test('returns the current coordinates after permission is granted', () async {
    final service = DeviceLocationService(
      isServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      getCurrentPosition: () async => _position(21.1717, 94.8589),
    );

    final point = await service.getCurrentLocation();

    expect(point.latitude, closeTo(21.1717, 0.0001));
    expect(point.longitude, closeTo(94.8589, 0.0001));
  });

  test('asks for permission when it was previously denied', () async {
    var requested = false;
    final service = DeviceLocationService(
      isServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        requested = true;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position(21.17, 94.86),
    );

    await service.getCurrentLocation();

    expect(requested, isTrue);
  });

  test('fails when the user denies location permission', () async {
    final service = DeviceLocationService(
      isServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async => LocationPermission.denied,
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(
        isA<DeviceLocationException>().having(
          (error) => error.code,
          'code',
          DeviceLocationError.permissionDenied,
        ),
      ),
    );
  });

  test('fails when location services are turned off', () async {
    final service = DeviceLocationService(
      isServiceEnabled: () async => false,
      checkPermission: () async => LocationPermission.whileInUse,
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(
        isA<DeviceLocationException>().having(
          (error) => error.code,
          'code',
          DeviceLocationError.servicesDisabled,
        ),
      ),
    );
  });
}
