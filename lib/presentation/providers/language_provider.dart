import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'language_code';
  static const List<String> _supported = ['en', 'my'];

  Locale _locale = const Locale('en');

  LanguageProvider() {
    Intl.defaultLocale = _locale.languageCode;
    _loadSavedLocale();
  }

  Locale get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    final resolved = _resolveLocale(locale);
    if (_locale == resolved) {
      return;
    }
    _locale = resolved;
    Intl.defaultLocale = _locale.languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _locale.languageCode);
    notifyListeners();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null || code.isEmpty) {
      return;
    }
    final resolved = _resolveLocale(Locale(code));
    if (_locale == resolved) {
      return;
    }
    _locale = resolved;
    Intl.defaultLocale = _locale.languageCode;
    notifyListeners();
  }

  Locale _resolveLocale(Locale locale) {
    if (_supported.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
    return const Locale('en');
  }
}
