enum TravelPlaceCategory { stay, food, transport }

TravelPlaceCategory _categoryFromJson(String rawCategory) {
  return switch (rawCategory) {
    'stay' => TravelPlaceCategory.stay,
    'food' => TravelPlaceCategory.food,
    'transport' => TravelPlaceCategory.transport,
    _ => throw FormatException(
      'Unsupported travel place category: $rawCategory',
    ),
  };
}

class TravelPlace {
  /// Indicative official bank rate used to make the offline catalogue useful
  /// for local travellers. Individual venues may quote a different rate.
  static const int mmkPerUsd = 3658;

  const TravelPlace({
    required this.id,
    required this.name,
    required this.nameMyanmar,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.summary,
    required this.summaryMyanmar,
    required this.note,
    required this.noteMyanmar,
    required this.priceEstimate,
    required this.priceEstimateMyanmar,
    required this.highlights,
    required this.highlightsMyanmar,
    required this.sourceName,
    required this.sourceUrl,
    required this.lastVerified,
    this.imageAsset,
    this.imageAttribution,
  });

  final String id;
  final String name;
  final String nameMyanmar;
  final TravelPlaceCategory category;
  final double latitude;
  final double longitude;
  final String area;
  final String summary;
  final String summaryMyanmar;
  final String note;
  final String noteMyanmar;
  final String priceEstimate;
  final String priceEstimateMyanmar;
  final List<String> highlights;
  final List<String> highlightsMyanmar;
  final String sourceName;
  final String sourceUrl;
  final DateTime lastVerified;
  final String? imageAsset;
  final String? imageAttribution;

  /// Converts the catalogue's USD planning estimates to MMK for display.
  /// Entries without a USD amount remain unchanged rather than inventing a
  /// local price.
  String get localPriceEstimate =>
      priceEstimate.replaceAllMapped(RegExp(r'US\$(\d+)'), (match) {
        final amount = int.parse(match.group(1)!);
        return 'MMK ${_groupThousands(amount * mmkPerUsd)}';
      });

  static String _groupThousands(int amount) {
    final digits = amount.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.add(digits.substring(end < 3 ? 0 : end - 3, end));
    }
    return groups.reversed.join(',');
  }

  factory TravelPlace.fromJson(Map<String, dynamic> json) {
    final category = _categoryFromJson(json['category'] as String);
    final area = json['area'] as String;
    final defaultSummary = switch (category) {
      TravelPlaceCategory.stay =>
        'A convenient stay in $area for exploring Bagan at your own pace.',
      TravelPlaceCategory.food => 'A dining stop in $area for your Bagan day.',
      TravelPlaceCategory.transport =>
        'A travel service or departure point in $area for getting around Bagan.',
    };
    final defaultSummaryMyanmar = switch (category) {
      TravelPlaceCategory.stay =>
        '$area တွင် တည်းခိုပြီး ပုဂံကို အေးဆေးစွာ လေ့လာနိုင်သောနေရာ။',
      TravelPlaceCategory.food =>
        '$area တွင် ခရီးသွားရင်း စားသောက်နားနေနိုင်သောနေရာ။',
      TravelPlaceCategory.transport =>
        '$area တွင် ပုဂံအတွင်း သွားလာရန် ဝန်ဆောင်မှု သို့မဟုတ် ထွက်ခွာရာနေရာ။',
    };
    final defaultNote = switch (category) {
      TravelPlaceCategory.stay =>
        'Contact the property for availability and arrival arrangements.',
      TravelPlaceCategory.food =>
        'Menus and opening times can change, so check before visiting.',
      TravelPlaceCategory.transport =>
        'Confirm schedules, fares, and pickup arrangements directly.',
    };
    final defaultNoteMyanmar = switch (category) {
      TravelPlaceCategory.stay =>
        'အခန်းလွတ်မှုနှင့် ရောက်ရှိလာမည့်အစီအစဉ်ကို တည်းခိုခန်းထံတွင် အတည်ပြုပါ။',
      TravelPlaceCategory.food =>
        'မီနူးနှင့် ဖွင့်ချိန် ပြောင်းလဲနိုင်သောကြောင့် မသွားမီ စစ်ဆေးပါ။',
      TravelPlaceCategory.transport =>
        'ထွက်ချိန်၊ နှုန်းထားနှင့် လာကြိုအစီအစဉ်ကို တိုက်ရိုက်အတည်ပြုပါ။',
    };
    final defaultPriceEstimate = switch (category) {
      TravelPlaceCategory.stay => 'Price on request',
      TravelPlaceCategory.food => 'Typical meal budget varies',
      TravelPlaceCategory.transport => 'Price varies by operator',
    };
    final defaultPriceEstimateMyanmar = switch (category) {
      TravelPlaceCategory.stay => 'စျေးနှုန်း မေးမြန်းရန်',
      TravelPlaceCategory.food => 'အစားအသောက်အသုံးစရိတ် ကွာခြားနိုင်သည်',
      TravelPlaceCategory.transport =>
        'ဝန်ဆောင်မှုပေးသူအလိုက် စျေးနှုန်းကွာခြားနိုင်သည်',
    };
    final defaultHighlights = switch (category) {
      TravelPlaceCategory.stay => <String>['Bagan base', area],
      TravelPlaceCategory.food => <String>['Dining stop', area],
      TravelPlaceCategory.transport => <String>['Travel planning', area],
    };

    return TravelPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String? ?? json['name'] as String,
      category: category,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      area: area,
      summary: json['summary'] as String? ?? defaultSummary,
      summaryMyanmar:
          json['summaryMyanmar'] as String? ?? defaultSummaryMyanmar,
      note: json['note'] as String? ?? defaultNote,
      noteMyanmar: json['noteMyanmar'] as String? ?? defaultNoteMyanmar,
      priceEstimate: json['priceEstimate'] as String? ?? defaultPriceEstimate,
      priceEstimateMyanmar:
          json['priceEstimateMyanmar'] as String? ??
          defaultPriceEstimateMyanmar,
      highlights:
          (json['highlights'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          defaultHighlights,
      highlightsMyanmar:
          (json['highlightsMyanmar'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          (json['highlights'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          defaultHighlights,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      lastVerified: DateTime.parse(json['lastVerified'] as String),
      imageAsset: json['imageAsset'] as String?,
      imageAttribution: json['imageAttribution'] as String?,
    );
  }
}
