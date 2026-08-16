import 'package:flutter/material.dart';

/// The shared visual system for the warm, tactile heritage-journal design.
class AppTheme {
  static const Color primaryColor = Color(0xFFA34A2A); // terracotta (spec)
  static const Color secondaryColor = Color(
    0xFF2B1D14,
  ); // deep lacquer brown (spec)
  static const Color accentColor = Color(0xFFC19A49); // antique gold (spec)
  static const Color backgroundColor = Color(
    0xFFF7F2E9,
  ); // ivory parchment (spec)
  static const Color cardColor = Color(0xFFFFFBF3);
  static const Color paperColor = Color(0xFFF0E4CE);
  static const Color textPrimary = Color(0xFF30251D);
  static const Color textSecondary = Color(0xFF786A5D);
  static const Color borderColor = Color(0xFFDCCCB3);
  static const Color errorColor = Color(0xFFC8463F);
  static const Color successColor = Color(0xFF4F7B54);

  static const _fallback = <String>['NotoSansMyanmar'];

  static TextTheme _buildTextTheme() {
    final base = ThemeData.light().textTheme;
    TextStyle display(double size) => TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.12,
      color: textPrimary,
    );
    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color? color,
      double height = 1.45,
    }) => TextStyle(
      fontFamily: 'Poppins',
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? textPrimary,
    );

    return base.copyWith(
      displayLarge: display(34),
      displayMedium: display(30),
      displaySmall: display(25),
      headlineLarge: display(23),
      headlineMedium: display(20),
      headlineSmall: display(18),
      titleLarge: body(16, weight: FontWeight.w700),
      titleMedium: body(14, weight: FontWeight.w700),
      titleSmall: body(12, weight: FontWeight.w700),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12, color: textSecondary, height: 1.35),
      labelLarge: body(
        14,
        weight: FontWeight.w700,
      ).copyWith(fontFeatures: const [FontFeature('smcp')], letterSpacing: 1.2),
      labelMedium: body(
        12,
        weight: FontWeight.w700,
      ).copyWith(fontFeatures: const [FontFeature('smcp')], letterSpacing: 1.2),
      labelSmall: body(
        10,
        weight: FontWeight.w700,
        color: textSecondary,
      ).copyWith(fontFeatures: const [FontFeature('smcp')], letterSpacing: 1.2),
    );
  }

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Poppins',
    fontFamilyFallback: _fallback,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: accentColor,
      onSecondary: textPrimary,
      surface: cardColor,
      onSurface: textPrimary,
      surfaceContainerHighest: paperColor,
      onSurfaceVariant: textSecondary,
      outline: borderColor,
      error: errorColor,
    ),
    textTheme: _buildTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        fontFamily: 'PlayfairDisplay',
        fontFamilyFallback: _fallback,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: borderColor),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
  );
}
