import 'lounge_promotion_decoder.dart';

class LoungeJsonDecoder {
  final Map<String, dynamic> json;
  late final promotion = LoungePromotionDecoder(json);
  LoungeJsonDecoder(this.json);

  double get pricePerHour =>
      _number([
        'price_per_hour',
        'hourly_rate',
        'hourly_price',
        'rate_per_hour',
        'price_per_hr',
        'hourly_fee',
        'min_price_per_hour',
        'min_price',
        'price',
      ]) ??
      0;

  double get rating => _number(['rating', 'avg_rating', 'average_rating']) ?? 0;

  double? _number(List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (value != null && value.isFinite) return value;
    }
    return null;
  }

  List<String> get categoryIcons {
    final icons = json['category_icons'];
    if (icons is List) return icons.map((e) => e.toString()).toList();
    final categories = json['categories'];
    if (categories is! List) return [];
    return categories
        .map(
          (e) => e is Map
              ? (e['icon'] ?? e['key'] ?? e['icon_key'] ?? '').toString()
              : e.toString(),
        )
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> get images {
    final data = json['images'] ?? json['gallery'];
    return data is List ? data.map((e) => e.toString()).toList() : [];
  }

  int? get totalReviews {
    final value = _number([
      'total_reviews',
      'reviews_count',
      'review_count',
      'total_review',
      'num_reviews',
      'ratings_count',
    ]);
    if (value != null) return value.toInt();
    final reviews = json['lounge_reviews'] ?? json['reviews'];
    return reviews is List ? reviews.length : null;
  }
}
