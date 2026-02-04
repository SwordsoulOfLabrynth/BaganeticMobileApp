import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
