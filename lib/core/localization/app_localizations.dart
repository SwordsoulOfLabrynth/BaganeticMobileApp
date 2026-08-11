import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  late final Map<String, dynamic> _localizedStrings;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (localizations == null) {
      throw StateError('AppLocalizations not found in context');
    }
    return localizations;
  }

  Future<bool> load() async {
    final jsonString = await rootBundle.loadString(
      'assets/languages/${locale.languageCode}.json',
    );
    _localizedStrings = json.decode(jsonString) as Map<String, dynamic>;

    final extraAssetPath = 'assets/languages/${locale.languageCode}_extra.json';
    try {
      final extraJsonString = await rootBundle.loadString(extraAssetPath);
      _localizedStrings.addAll(
        json.decode(extraJsonString) as Map<String, dynamic>,
      );
    } on FlutterError {
      // Extra locale overlays are optional.
    }

    return true;
  }

  String translate(String key, {Map<String, String>? args}) {
    final value = _localizedStrings[key];
    var text = value is String ? value : key;
    if (args != null) {
      for (final entry in args.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }

  String translateOr(String key, String fallback, {Map<String, String>? args}) {
    final value = _localizedStrings[key];
    if (value is String && value.isNotEmpty) {
      return translate(key, args: args);
    }
    return fallback;
  }

  String pagodaName(String id, String fallback, {String? remoteMyanmar}) {
    if (locale.languageCode == 'my' &&
        remoteMyanmar?.trim().isNotEmpty == true) {
      return remoteMyanmar!.trim();
    }
    return translateOr('pagoda.$id.name', fallback);
  }

  String pagodaDescription(
    String id,
    String fallback, {
    String? remoteMyanmar,
  }) {
    if (locale.languageCode == 'my' &&
        remoteMyanmar?.trim().isNotEmpty == true) {
      return remoteMyanmar!.trim();
    }
    return _translatePagodaField('pagoda.$id.description', fallback);
  }

  String pagodaHistory(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.history', fallback);
  }

  String pagodaArchitecture(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.architecture', fallback);
  }

  String pagodaLegends(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.legends', fallback);
  }

  String pagodaReligiousImportance(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.religiousImportance', fallback);
  }

  String pagodaPreservation(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.preservation', fallback);
  }

  String pagodaBestTime(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.bestTime', fallback);
  }

  String pagodaFinalWords(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.finalWords', fallback);
  }

  String pagodaVisitorLocation(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.visitorLocation', fallback);
  }

  String pagodaOpeningHours(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.openingHours', fallback);
  }

  String pagodaDressCode(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.dressCode', fallback);
  }

  String pagodaEntranceFee(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.entranceFee', fallback);
  }

  String pagodaPhotographyRules(String id, String fallback) {
    return _translatePagodaField('pagoda.$id.photographyRules', fallback);
  }

  String pagodaUniqueFeatureTitle(String id, int index, String fallback) {
    return _translatePagodaField(
      'pagoda.$id.uniqueFeatures.$index.title',
      fallback,
    );
  }

  String pagodaUniqueFeatureDescription(String id, int index, String fallback) {
    return _translatePagodaField(
      'pagoda.$id.uniqueFeatures.$index.description',
      fallback,
    );
  }

  String _translatePagodaField(String key, String fallback) {
    final translated = translateOr(key, fallback);

    if (locale.languageCode != 'my') {
      return translated;
    }

    if (_containsUnreviewedLatinContent(translated)) {
      return translateOr('common.translationPending', fallback);
    }

    return translated;
  }

  bool _containsUnreviewedLatinContent(String text) {
    // Pagoda names are localized separately. For descriptive fields, a Latin
    // word means the Myanmar copy is mixed or not yet editorially reviewed.
    return RegExp(r'[A-Za-z]{2,}').hasMatch(text);
  }

  String categoryLabel(String category) {
    switch (category) {
      case 'All':
        return translate('category.all');
      case 'Temple':
        return translate('category.temple');
      case 'Pagoda':
        return translate('category.pagoda');
      default:
        return category;
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'my'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
