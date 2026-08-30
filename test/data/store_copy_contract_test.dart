import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English legal copy is present for store listing', () {
    final json = jsonDecode(
      File('assets/languages/en.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(json['legal.privacyTitle'], 'Privacy Policy');
    expect(json['legal.termsTitle'], 'Terms of Use');
    expect(
      json['legal.privacyBody'] as String,
      contains('admin@baganetic.com'),
    );
    expect(json['profile.deleteAccount'], isNotEmpty);
    expect(json['map.osmAttribution'], contains('OpenStreetMap'));
    expect(json['map.locateMe'], isNotEmpty);
    expect(json['legal.privacyBody'] as String, contains('Location'));
  });
}
