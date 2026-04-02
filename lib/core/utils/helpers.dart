import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/trip_model.dart';
import '../localization/app_localizations.dart';

class Helpers {
  // Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // Format distance
  static String formatDistance(BuildContext context, double distanceKm) {
    final l10n = AppLocalizations.of(context);
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).toStringAsFixed(0);
      return '$meters ${l10n.translate('unit.meter')}';
    }
    return '${distanceKm.toStringAsFixed(2)} ${l10n.translate('unit.kilometer')}';
  }

  static String formatDuration(BuildContext context, int totalMinutes) {
    final l10n = AppLocalizations.of(context);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes ${l10n.translate('common.minutesShort')}';
    }

    final hourLabel = l10n.translate('common.hoursShort');
    final minuteLabel = l10n.translate('common.minutesShort');
    if (minutes == 0) {
      return '$hours $hourLabel';
    }
    return '$hours $hourLabel $minutes $minuteLabel';
  }

  static String formatSpeed(BuildContext context, double speedKph) {
    final l10n = AppLocalizations.of(context);
    final speedText = speedKph == speedKph.roundToDouble()
        ? speedKph.toStringAsFixed(0)
        : speedKph.toStringAsFixed(1);
    return '$speedText ${l10n.translate('unit.kilometersPerHour')}';
  }

  static String transportModeLabel(
    BuildContext context,
    TripTransportMode mode,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case TripTransportMode.walk:
        return l10n.translate('trip.transportMode.walk');
      case TripTransportMode.bike:
        return l10n.translate('trip.transportMode.bike');
      case TripTransportMode.car:
        return l10n.translate('trip.transportMode.car');
    }
  }

  static IconData transportModeIcon(TripTransportMode mode) {
    switch (mode) {
      case TripTransportMode.walk:
        return Icons.directions_walk;
      case TripTransportMode.bike:
        return Icons.directions_bike;
      case TripTransportMode.car:
        return Icons.directions_car;
    }
  }

  // Format date
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd(Intl.defaultLocale).format(date);
  }

  // Format time
  static String formatTime(DateTime time) {
    return DateFormat.jm(Intl.defaultLocale).format(time.toLocal());
  }

  // Show snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFE74C3C) : Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
