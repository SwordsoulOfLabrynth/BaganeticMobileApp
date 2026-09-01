import 'package:baganetic_mobile/core/localization/app_localizations.dart';
import 'package:baganetic_mobile/data/models/travel_place.dart';
import 'package:baganetic_mobile/presentation/screens/discover/travel_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _places = [
  TravelPlace(
    id: 'stay',
    name: 'Bagan Stay',
    nameMyanmar: 'Bagan Stay',
    category: TravelPlaceCategory.stay,
    latitude: 21.17,
    longitude: 94.86,
    area: 'Old Bagan',
    summary: 'A calm place to stay.',
    summaryMyanmar: 'တည်းခိုရန်နေရာ။',
    note: 'Confirm before booking.',
    noteMyanmar: 'မသွားမီ အတည်ပြုပါ။',
    priceEstimate: 'From US\$55 / night',
    priceEstimateMyanmar: 'US\$55 မှ',
    highlights: ['Riverside setting', 'Old Bagan base'],
    highlightsMyanmar: ['မြစ်ကမ်းဘေး', 'ပုဂံဟောင်း'],
    sourceName: 'Test source',
    sourceUrl: 'https://example.com/stay',
    lastVerified: DateTime(2026, 9, 1),
  ),
  TravelPlace(
    id: 'food',
    name: 'Bagan Food',
    nameMyanmar: 'Bagan Food',
    category: TravelPlaceCategory.food,
    latitude: 21.18,
    longitude: 94.87,
    area: 'Nyaung-U',
    summary: 'A place to eat.',
    summaryMyanmar: 'စားသောက်ရန်နေရာ။',
    note: 'Check the menu.',
    noteMyanmar: 'မီနူးကို စစ်ဆေးပါ။',
    priceEstimate: 'Approx. US\$4–12 / person',
    priceEstimateMyanmar: 'တစ်ဦးလျှင် US\$4–12 ခန့်',
    highlights: ['Casual dining', 'Nyaung-U'],
    highlightsMyanmar: ['သာမန်စားသောက်မှု', 'ညောင်ဦး'],
    sourceName: 'Test source',
    sourceUrl: 'https://example.com/food',
    lastVerified: DateTime(2026, 9, 1),
  ),
];

void main() {
  testWidgets('filters the customer discovery list by category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: TravelDiscoveryScreen(places: _places),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bagan Stay'), findsOneWidget);
    expect(find.text('Bagan Food'), findsOneWidget);
    expect(find.text('From MMK 201,190 / night'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Bagan Food'), findsOneWidget);
    expect(find.text('Bagan Stay'), findsNothing);

    await tester.tap(find.text('Bagan Food'));
    await tester.pumpAndSettle();

    expect(find.text('Estimated price'), findsOneWidget);
    expect(
      find.text('USD reference: Approx. US\$4–12 / person'),
      findsOneWidget,
    );
    expect(find.text('Why it may suit your trip'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsNothing);
  });
}
