import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  // Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1, double lon1, double lat2, double lon2
  ) {
    const double earthRadius = 6371; // km
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
  
  // Format distance
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }
  
  // Format date
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  // Format time
  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }
  
  // Show snackbar
  static void showSnackBar(context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFE74C3C) : Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
