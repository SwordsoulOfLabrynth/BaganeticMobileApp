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
    id: 'scenery',
    name: 'Bagan Dawn Field',
    nameMyanmar: 'ပုဂံ အရုဏ်တက် လယ်ကွင်း',
    category: TravelPlaceCategory.scenery,
    latitude: 21.16,
    longitude: 94.88,
    area: 'Old Bagan',
    summary: 'A ground-level view for first light.',
    summaryMyanmar: 'အရုဏ်တက်အလင်းရောင်အတွက် မြေပြင်ရှုခင်း။',
    note: 'Do not climb monuments.',
    noteMyanmar: 'အဆောက်အအုံများ မတက်ပါနှင့်။',
    priceEstimate: 'Ground-level photo spot',
    priceEstimateMyanmar: 'မြေပြင်မှ ဓာတ်ပုံရိုက်နိုင်သောနေရာ',
    highlights: ['Dawn sky', 'Ground-level'],
    highlightsMyanmar: ['အရုဏ်တက်ကောင်းကင်', 'မြေပြင်'],
    bestTime: 'Sunrise — arrive 45 minutes before sunrise',
    bestTimeMyanmar: 'နေမထွက်မီ ၄၅ မိနစ်',
    seasonNote: 'Clear mornings bring stronger layers.',
    seasonNoteMyanmar: 'ကောင်းကင်ရှင်းသောမနက်ခင်းက အလွှာများပိုပေါ်စေသည်။',
    photoTip: 'Stay on public ground.',
    photoTipMyanmar: 'အများသုံးမြေပြင်မှသာ ရိုက်ပါ။',
    sourceName: 'Test source',
    sourceUrl: 'https://example.com/scenery',
    lastVerified: DateTime(2026, 9, 2),
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
    expect(find.text('Bagan Dawn Field'), findsOneWidget);
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

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo spots'));
    await tester.pumpAndSettle();

    expect(find.text('Bagan Dawn Field'), findsOneWidget);
    expect(find.text('Sunrise — arrive 45 minutes before sunrise'), findsOneWidget);

    await tester.tap(find.text('Bagan Dawn Field'));
    await tester.pumpAndSettle();

    expect(find.text('Best light'), findsOneWidget);
    expect(find.text('Seasonal light'), findsOneWidget);
    expect(find.text('Photo tip'), findsOneWidget);
  });
}
