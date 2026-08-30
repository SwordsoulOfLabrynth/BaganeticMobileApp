import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum DeviceLocationError {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class DeviceLocationException implements Exception {
  DeviceLocationException(this.code);

  final DeviceLocationError code;
}

class DeviceLocationService {
  DeviceLocationService({
    Future<bool> Function()? isServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function()? getCurrentPosition,
    Stream<Position> Function()? watchPosition,
    Future<bool> Function()? openAppSettings,
    Future<bool> Function()? openLocationSettings,
  }) : _isServiceEnabled =
           isServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getCurrentPosition =
           getCurrentPosition ??
           (() => Geolocator.getCurrentPosition(
             locationSettings: locationSettings,
           )),
       _watchPosition =
           watchPosition ??
           (() => Geolocator.getPositionStream(
             locationSettings: locationSettings,
           )),
       _openAppSettings = openAppSettings ?? Geolocator.openAppSettings,
       _openLocationSettings =
           openLocationSettings ?? Geolocator.openLocationSettings;

  final Future<bool> Function() _isServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function() _getCurrentPosition;
  final Stream<Position> Function() _watchPosition;
  final Future<bool> Function() _openAppSettings;
  final Future<bool> Function() _openLocationSettings;

  static LocationSettings get locationSettings {
    const accuracy = LocationAccuracy.high;
    const distanceFilter = 8;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 4),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
  }

  Future<void> openAppSettings() => _openAppSettings();

  Future<void> openLocationSettings() => _openLocationSettings();

  Future<LatLng> getCurrentLocation() async {
    await ensurePermission();
    try {
      final position = await _getCurrentPosition();
      return _toLatLng(position);
    } on DeviceLocationException {
      rethrow;
    } catch (_) {
      throw DeviceLocationException(DeviceLocationError.unavailable);
    }
  }

  Stream<LatLng> watchLocation() async* {
    await ensurePermission();
    try {
      yield* _watchPosition().map(_toLatLng);
    } on DeviceLocationException {
      rethrow;
    } catch (_) {
      throw DeviceLocationException(DeviceLocationError.unavailable);
    }
  }

  Future<void> ensurePermission() async {
    final enabled = await _isServiceEnabled();
    if (!enabled) {
      throw DeviceLocationException(DeviceLocationError.servicesDisabled);
    }

    var permission = await _checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw DeviceLocationException(DeviceLocationError.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw DeviceLocationException(
        DeviceLocationError.permissionDeniedForever,
      );
    }
  }

  LatLng _toLatLng(Position position) =>
      LatLng(position.latitude, position.longitude);
}
