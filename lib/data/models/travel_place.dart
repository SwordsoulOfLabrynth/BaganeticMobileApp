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
    final defaultSummary = switch (category) {
      TravelPlaceCategory.stay => 'Map-verified place to stay in Bagan.',
      TravelPlaceCategory.food => 'Map-verified place to eat or have a drink in Bagan.',
      TravelPlaceCategory.transport =>
        'Map-verified transport service or departure point in Bagan.',
    };
    final defaultSummaryMyanmar = switch (category) {
      TravelPlaceCategory.stay => 'ပုဂံရှိ မြေပုံမှ အတည်ပြုထားသော တည်းခိုရာနေရာ။',
      TravelPlaceCategory.food => 'ပုဂံရှိ မြေပုံမှ အတည်ပြုထားသော စားသောက်ရာနေရာ။',
      TravelPlaceCategory.transport =>
        'ပုဂံရှိ မြေပုံမှ အတည်ပြုထားသော သွားလာရေးဝန်ဆောင်မှု သို့မဟုတ် ထွက်ခွာရာနေရာ။',
    };
    const defaultNote =
        'Confirm current opening status, prices, and availability directly before making a special trip.';
    const defaultNoteMyanmar =
        'အထူးသွားရောက်မည်ဆိုပါက လက်ရှိဖွင့်လှစ်မှု၊ နှုန်းထားနှင့် ရရှိနိုင်မှုကို တိုက်ရိုက်အတည်ပြုပါ။';

    return TravelPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      nameMyanmar: json['nameMyanmar'] as String? ?? json['name'] as String,
      category: category,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      area: json['area'] as String,
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
