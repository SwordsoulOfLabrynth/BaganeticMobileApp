enum TravelPlaceCategory { stay, food, transport }

TravelPlaceCategory _categoryFromJson(String rawCategory) {
  return switch (rawCategory) {
    'stay' => TravelPlaceCategory.stay,
    'food' => TravelPlaceCategory.food,
    'transport' => TravelPlaceCategory.transport,
    _ => throw FormatException('Unsupported travel place category: $rawCategory'),
  };
}

class TravelPlace {
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
    required this.sourceName,
    required this.sourceUrl,
    required this.lastVerified,
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
  final String sourceName;
  final String sourceUrl;
  final DateTime lastVerified;

  factory TravelPlace.fromJson(Map<String, dynamic> json) {
    final category = _categoryFromJson(json['category'] as String);
    final area = json['area'] as String;
    final defaultSummary = switch (category) {
      TravelPlaceCategory.stay =>
        'A convenient stay in $area for exploring Bagan at your own pace.',
      TravelPlaceCategory.food =>
        'A dining stop in $area for your Bagan day.',
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

    return TravelPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String? ?? json['name'] as String,
      category: category,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      area: area,
      summary: json['summary'] as String? ?? defaultSummary,
      summaryMyanmar: json['summaryMyanmar'] as String? ?? defaultSummaryMyanmar,
      note: json['note'] as String? ?? defaultNote,
      noteMyanmar: json['noteMyanmar'] as String? ?? defaultNoteMyanmar,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      lastVerified: DateTime.parse(json['lastVerified'] as String),
    );
  }
}
