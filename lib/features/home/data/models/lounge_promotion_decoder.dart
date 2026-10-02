import 'package:playspot/core/utils/json_value_reader.dart';

class LoungePromotionDecoder {
  final Map<String, dynamic> json;
  late final Map<String, dynamic> active = _activePromotion();
  LoungePromotionDecoder(this.json);

  Map<String, dynamic> _activePromotion() {
    final data =
        json['promotions'] ??
        json['active_promotion'] ??
        json['promotion'] ??
        json['active_promo'] ??
        json['promo'];
    final promotions = data is List ? data : [data];
    for (final entry in promotions.whereType<Map>()) {
      if (entry['is_active'] == false) continue;
      final rawExpiry =
          entry['expires_at'] ??
          entry['end_date'] ??
          entry['discount_expires_at'];
      final expiry = DateTime.tryParse('$rawExpiry');
      if (expiry != null && !expiry.isAfter(DateTime.now())) continue;
      return Map<String, dynamic>.from(entry);
    }
    return {};
  }

  int get percentage {
    final joined = _percentage(active);
    return joined > 0 ? joined : _percentage(json);
  }

  int _percentage(Map<String, dynamic> data) =>
      ((data['discount_percentage'] ??
                  data['discount_value'] ??
                  data['discount'])
              as num?)
          ?.toInt() ??
      0;

  String? title(String language) =>
      JsonValueReader.firstNonBlank(json, [
        'discount_title_$language',
        'promo_title_$language',
        'tag_$language',
        'title_$language',
      ]) ??
      JsonValueReader.firstNonBlank(active, [
        'tag_$language',
        'title_$language',
        'tag',
        'title',
      ]);

  DateTime? get expiresAt => DateTime.tryParse(
    '${active['expires_at'] ?? active['end_date'] ?? active['discount_expires_at'] ?? json['discount_expires_at'] ?? json['expires_at']}',
  );

  bool get hasDiscount =>
      json['has_discount'] == true ||
      json['is_discount_active'] == true ||
      json['has_active_promo'] == true ||
      percentage > 0 ||
      (title('ar')?.isNotEmpty ?? false);
}
