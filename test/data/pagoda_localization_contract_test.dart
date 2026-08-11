import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current;

  dynamic readJson(String relativePath) {
    final file = File(
      '${projectRoot.path}${Platform.pathSeparator}$relativePath',
    );
    return jsonDecode(file.readAsStringSync());
  }

  test('every pagoda has a Myanmar display name', () {
    final pagodas =
        readJson('assets/data/sample_pagodas.json') as List<dynamic>;
    final translations = <String, dynamic>{
      ...(readJson('assets/languages/my.json') as Map<String, dynamic>),
      ...(readJson('assets/languages/my_extra.json') as Map<String, dynamic>),
    };

    for (final pagoda in pagodas.cast<Map<String, dynamic>>()) {
      final id = pagoda['id'] as String;
      final name = translations['pagoda.$id.name'];
      expect(name, isA<String>(), reason: '$id is missing a Myanmar name');
      expect(
        name as String,
        matches(RegExp(r'[\u1000-\u109F]')),
        reason: '$id falls back to a non-Myanmar display name',
      );
    }
  });

  test('reviewed Burmese names retain their canonical spellings', () {
    final translations = <String, dynamic>{
      ...(readJson('assets/languages/my.json') as Map<String, dynamic>),
      ...(readJson('assets/languages/my_extra.json') as Map<String, dynamic>),
    };

    expect(translations['pagoda.gawdawpalin.name'], 'ကန်တော့ပလ္လင်ဘုရား');
    expect(translations['pagoda.seinnyetnyiama.name'], 'စိမ်းညက်အစ်မ ဂူဘုရား');
    expect(translations['pagoda.ngakywenataung.name'], 'ငကျွဲနားတောင်းစေတီ');
    expect(translations['pagoda.bulethi.name'], 'ဗူးလယ်သီးဘုရား');
    expect(translations['pagoda.tuywintaung.name'], 'တုရင်တောင် စေတီ');
  });

  test('retired Burmese aliases do not reappear in pagoda copy', () {
    final translations = <String, dynamic>{
      ...(readJson('assets/languages/my.json') as Map<String, dynamic>),
      ...(readJson('assets/languages/my_extra.json') as Map<String, dynamic>),
    };
    final copy = jsonEncode(translations);
    const retiredAliases = [
      'ဘူလေသီ',
      'ဗူးလည်သီး',
      'ရွှေစန္ဒာ',
      'မြဇီဒီ',
      'သုမင်ကြီး',
      'ရွှေလဲကျလွန်း',
      'တန်ကြည်တောင်',
      'သပိတ်မောက်',
      'မီးညိမ်းကုန်း',
      'မိညိမ်းကုန်း',
      'သက်ကြီးမုနိ',
      'သာကီမုနိ',
      'လက္ခံဆောင်',
      'ငကြီးနတ်တောင်',
      'ငါးကျွဲနားတောင်း',
      'တူရွင်းတောင်',
    ];

    for (final alias in retiredAliases) {
      expect(copy, isNot(contains(alias)), reason: '$alias must not be shown');
    }
  });
}
