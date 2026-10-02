import 'package:playspot/core/utils/json_value_reader.dart';

class RoomPromotionDecoder {
  final Map<String, dynamic> json;
  late final Map<String, dynamic> active = _active();
  RoomPromotionDecoder(this.json);

  Map<String, dynamic> _active() {
    final raw =
        json['promotions'] ??
        json['active_promotion'] ??
        json['promotion'] ??
        json['offer'] ??
        json['active_promo'] ??
        json['promo'];
    final list = raw is List ? raw : [raw];
    for (final item in list.whereType<Map>()) {
      if (item['is_active'] == false) continue;
      final rawExpiry =
          item['expires_at'] ?? item['end_date'] ?? item['discount_expires_at'];
      final expiry = DateTime.tryParse('$rawExpiry');
      if (expiry != null && !expiry.isAfter(DateTime.now())) continue;
      return Map<String, dynamic>.from(item);
    }
    return {};
  }

  double _value(Map<String, dynamic> data) =>
      ((data['discount_value'] ??
                  data['discount_percentage'] ??
                  data['discount_amount'] ??
                  data['discount'] ??
                  data['value'] ??
                  data['promo_discount_value'])
              as num?)
          ?.toDouble() ??
      0;

  double get discountValue =>
      _value(active) > 0 ? _value(active) : _value(json);

  String get discountType {
    final joined = JsonValueReader.firstNonBlank(active, [
      'discount_type',
      'type',
      'promo_type',
    ]);
    if (joined != null) return joined;
    if (active.containsKey('discount_percentage') ||
        active.containsKey('percentage')) {
      return 'percentage';
    }
    return JsonValueReader.firstNonBlank(json, [
          'discount_type',
          'promo_discount_type',
          'type',
        ]) ??
        'percentage';
  }

  bool get hasActivePromo =>
      _value(active) > 0 ||
      json['has_active_promo'] == true ||
      json['has_discount'] == true ||
      json['is_discount_active'] == true ||
      discountValue > 0;

  String? tag(String language) =>
      JsonValueReader.firstNonBlank(active, [
        'tag_$language',
        'title_$language',
        'name_$language',
        'promo_title_$language',
        'tag',
        'title',
        'name',
      ]) ??
      JsonValueReader.firstNonBlank(json, [
        'tag_$language',
        'promo_tag_$language',
        'title_$language',
        'discount_title_$language',
        'tag',
        'promo_tag',
        'title',
        'discount_title',
      ]);
}
