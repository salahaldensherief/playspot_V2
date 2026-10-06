import 'room_model.dart';
import 'room_promotion_decoder.dart';

class RoomJsonDecoder {
  final Map<String, dynamic> json;
  late final promotion = RoomPromotionDecoder(json);
  RoomJsonDecoder(this.json);

  RoomModel decode() => RoomModel(
    id: '${json['id'] ?? ''}',
    loungeId: '${json['lounge_id'] ?? ''}',
    nameAr: '${json['name_ar'] ?? json['name'] ?? json['name_en'] ?? ''}',
    nameEn: '${json['name_en'] ?? json['name'] ?? json['name_ar'] ?? ''}',
    activityNames: activities,
    spaceType:
        json['space_type_label']?.toString() ??
        _spaceType('label') ??
        (json['space_type'] ?? json['space_type_name'])?.toString(),
    spaceTypeName:
        _spaceType('name') ??
        (json['space_type_slug'] ??
                json['space_type'] ??
                json['space_type_name'])
            ?.toString(),
    maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 0,
    hourlyRateSingle: (json['hourly_rate_single'] as num?)?.toDouble() ?? 0,
    hourlyRateMulti: (json['hourly_rate_multi'] as num?)?.toDouble() ?? 0,
    extraControllerPrice:
        (json['extra_controller_price'] as num?)?.toDouble() ?? 0,
    isAvailable: json['is_available'] as bool? ?? true,
    status: '${json['status'] ?? 'available'}',
    images: _strings(
      json['images'] ?? (json['photo_url'] == null ? [] : [json['photo_url']]),
    ),
    featuresAr: _strings(json['features_ar'] ?? json['features']),
    featuresEn: _strings(json['features_en'] ?? json['features']),
    controllersCount: (json['controllers_count'] as num?)?.toInt() ?? 0,
    screenSize: '${json['screen_size'] ?? ''}',
    hasActivePromo: promotion.hasActivePromo,
    promoTagAr: promotion.tag('ar'),
    promoTagEn: promotion.tag('en'),
    promoDiscountValue: promotion.discountValue,
    promoDiscountType: promotion.discountType,
  );

  String? _spaceType(String field) {
    final raw = json['space_types'];
    final item = raw is List ? (raw.isEmpty ? null : raw.first) : raw;
    return item is Map ? item[field]?.toString() : null;
  }

  List<String> get activities {
    final activityNames = _activityTypeNames();
    if (activityNames.isNotEmpty) return activityNames;

    final legacyNames = _legacyCategoryNames();
    if (legacyNames.isNotEmpty) return legacyNames;

    return _strings(json['activity_names']);
  }

  List<String> _activityTypeNames() {
    final activities = json['room_activities'];
    if (activities is! List) return const [];

    return activities
        .whereType<Map>()
        .map((item) {
          final data = item['activity_types'];
          if (data is! Map) return null;
          return (data['label'] ?? data['name'])?.toString();
        })
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _legacyCategoryNames() {
    final categories = json['room_categories'];
    if (categories is! List) return const [];

    return categories
        .whereType<Map>()
        .map((item) {
          final data = item['categories'];
          return data is Map
              ? (data['name_en'] ?? data['name'])?.toString()
              : null;
        })
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _strings(Object? data) => data is List
      ? data
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
      : [];
}
