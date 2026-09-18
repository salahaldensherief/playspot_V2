import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';

class RoomModel extends Equatable {
  final String id;
  final String loungeId;
  final String nameAr;
  final String nameEn;
  final List<String> activityNames;
  final String? spaceType;
  final String? spaceTypeName;
  final int maxCapacity;
  final double hourlyRateSingle;
  final double hourlyRateMulti;
  final double extraControllerPrice;
  final bool isAvailable;
  final String status;
  final List<String> images;
  final List<String> featuresAr;
  final List<String> featuresEn;
  final int controllersCount;
  final String screenSize;
  final bool hasActivePromo;
  final String? promoTagAr;
  final String? promoTagEn;
  final double promoDiscountValue;
  final String? promoDiscountType;

  const RoomModel({
    required this.id,
    required this.loungeId,
    required this.nameAr,
    required this.nameEn,
    required this.activityNames,
    this.spaceType,
    this.spaceTypeName,
    required this.maxCapacity,
    required this.hourlyRateSingle,
    required this.hourlyRateMulti,
    this.extraControllerPrice = 0.0,
    required this.isAvailable,
    this.status = 'available',
    required this.images,
    required this.featuresAr,
    required this.featuresEn,
    this.controllersCount = 2,
    this.screenSize = '43"',
    this.hasActivePromo = false,
    this.promoTagAr,
    this.promoTagEn,
    this.promoDiscountValue = 0.0,
    this.promoDiscountType,
  });

  @override
  List<Object?> get props => [
    id,
    loungeId,
    nameAr,
    nameEn,
    activityNames,
    spaceType,
    spaceTypeName,
    maxCapacity,
    hourlyRateSingle,
    hourlyRateMulti,
    extraControllerPrice,
    isAvailable,
    status,
    images,
    featuresAr,
    featuresEn,
    controllersCount,
    screenSize,
    hasActivePromo,
    promoTagAr,
    promoTagEn,
    promoDiscountValue,
    promoDiscountType,
  ];

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
  List<String> getFeatures(bool isArabic) => isArabic ? featuresAr : featuresEn;
  String? getPromoTag(bool isArabic) => isArabic ? promoTagAr : promoTagEn;

  int get capacity => maxCapacity;
  double get hourlyRate => hourlyRateSingle;

  double get effectivePrice => effectivePriceSingle;

  double get effectivePriceSingle {
    if (!hasActivePromo || promoDiscountValue <= 0) return hourlyRateSingle;

    if (promoDiscountType == 'percentage') {
      return hourlyRateSingle * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (hourlyRateSingle - promoDiscountValue).clamp(0.0, double.infinity);
    }
    return hourlyRateSingle;
  }

  double get effectivePriceMulti {
    if (!hasActivePromo || promoDiscountValue <= 0) return hourlyRateMulti;

    if (promoDiscountType == 'percentage') {
      return hourlyRateMulti * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (hourlyRateMulti - promoDiscountValue).clamp(0.0, double.infinity);
    }
    return hourlyRateMulti;
  }

  bool get isVR => activityNames.any((a) => a.toLowerCase().contains('vr'));
  bool get isSimulator => activityNames.any((a) => a.toLowerCase().contains('simulator'));
  bool get isOpenArea => spaceTypeName == 'open_area';
  bool get isVIP => spaceTypeName == 'vip_room';
  bool get isStandard => spaceTypeName == 'standard_room';
  bool get isOccupied => status.trim().toLowerCase() == 'occupied';

  String getDisplayTitle(bool isArabic) {
    if (spaceTypeName == 'open_area') {
      return isArabic ? "شاشة / جهاز $nameAr" : "Station / Device $nameEn";
    }
    return isArabic ? "غرفة $nameAr" : "Room $nameEn";
  }

  String spaceTypeLabel(bool isArabic) {
    if (spaceTypeName == 'open_area') return isArabic ? 'صالة مفتوحة' : 'OPEN AREA';
    if (spaceTypeName == 'vip_room') return isArabic ? 'غرفة VIP' : 'VIP ROOM';
    return isArabic ? 'غرفة عادية' : 'STANDARD ROOM';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lounge_id': loungeId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'activity_names': activityNames,
      'space_type_name': spaceType,
      'space_type_slug': spaceTypeName,
      'max_capacity': maxCapacity,
      'hourly_rate_single': hourlyRateSingle,
      'hourly_rate_multi': hourlyRateMulti,
      'extra_controller_price': extraControllerPrice,
      'is_available': isAvailable,
      'status': status,
      'images': images,
      'features_ar': featuresAr,
      'features_en': featuresEn,
      'controllers_count': controllersCount,
      'screen_size': screenSize,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    try {
      final List? roomCats = json['room_categories'] as List?;
      final List<String> activities = [];
      if (roomCats != null) {
        for (var cat in roomCats) {
          if (cat['categories'] != null && cat['categories']['name_en'] != null) {
            activities.add(cat['categories']['name_en']);
          }
        }
      }

      final singleRate = (json['hourly_rate_single'] as num?)?.toDouble() ?? 0.0;
      final multiRate = (json['hourly_rate_multi'] as num?)?.toDouble() ?? 0.0;
      final maxCap = (json['max_capacity'] as num?)?.toInt() ?? 4;

      return RoomModel(
        id: json['id']?.toString() ?? '',
        loungeId: json['lounge_id']?.toString() ?? '',
        nameAr: json['name_ar']?.toString() ?? json['name']?.toString() ?? json['name_en']?.toString() ?? '',
        nameEn: json['name_en']?.toString() ?? json['name']?.toString() ?? '',
        activityNames: activities.isNotEmpty
            ? activities
            : (json['activity_names'] != null ? List<String>.from(json['activity_names']) : []),
        spaceType: json['space_type_label'] ??
            (json['space_types'] is List
                ? (json['space_types'] as List).isNotEmpty ? (json['space_types'] as List).first['label'] : null
                : json['space_types']?['label']) ??
            json['space_type']?.toString() ??
            json['space_type_name']?.toString(),
        spaceTypeName: (json['space_types'] is List
            ? (json['space_types'] as List).isNotEmpty ? (json['space_types'] as List).first['name'] : null
            : json['space_types']?['name']) ??
            json['space_type_slug']?.toString() ??
            json['space_type']?.toString() ??
            json['space_type_name']?.toString(),
        maxCapacity: maxCap,
        hourlyRateSingle: singleRate,
        hourlyRateMulti: multiRate,
        extraControllerPrice: (json['extra_controller_price'] as num?)?.toDouble() ?? 0.0,
        isAvailable: json['is_available'] ?? true,
        status: json['status']?.toString() ?? 'available',
        images: json['images'] != null
            ? List<String>.from(json['images'])
            : (json['photo_url'] != null ? [json['photo_url'].toString()] : []),
        featuresAr: json['features_ar'] != null
            ? List<String>.from(json['features_ar'])
            : (json['features'] != null && json['features'] is List ? List<String>.from(json['features']) : []),
        featuresEn: json['features_en'] != null
            ? List<String>.from(json['features_en'])
            : (json['features'] != null && json['features'] is List ? List<String>.from(json['features']) : []),
        controllersCount: (json['controllers_count'] as num?)?.toInt() ?? 2,
        screenSize: json['screen_size']?.toString() ?? '43"',
        hasActivePromo: _parsePromoStatus(json, json['promotions'] ?? json['active_promotion'] ?? json['promotion'] ?? json['offer'] ?? json['active_promo'] ?? json['promo']),
        promoTagAr: _parsePromoTag(json, json['promotions'] ?? json['active_promotion'] ?? json['promotion'] ?? json['offer'] ?? json['active_promo'] ?? json['promo'], true),
        promoTagEn: _parsePromoTag(json, json['promotions'] ?? json['active_promotion'] ?? json['promotion'] ?? json['offer'] ?? json['active_promo'] ?? json['promo'], false),
        promoDiscountValue: _parsePromoDiscountValue(json, json['promotions'] ?? json['active_promotion'] ?? json['promotion'] ?? json['offer'] ?? json['active_promo'] ?? json['promo']),
        promoDiscountType: _parsePromoDiscountType(json, json['promotions'] ?? json['active_promotion'] ?? json['promotion'] ?? json['offer'] ?? json['active_promo'] ?? json['promo']),
      );
    } catch (e) {
      dev.log("Error parsing RoomModel: $e");
      rethrow;
    }
  }

  static double _parsePromoDiscountValue(dynamic json, dynamic promoData) {
    final activePromo = _getActivePromo(promoData);
    if (activePromo != null) {
      final val = (activePromo['discount_value'] as num?)?.toDouble() ??
          (activePromo['discount_percentage'] as num?)?.toDouble() ??
          (activePromo['discount_amount'] as num?)?.toDouble() ??
          (activePromo['discount'] as num?)?.toDouble() ??
          (activePromo['value'] as num?)?.toDouble() ??
          0.0;
      if (val > 0) return val;
    }
    final flatVal = (json['discount_value'] as num?)?.toDouble() ??
        (json['discount_percentage'] as num?)?.toDouble() ??
        (json['discount_amount'] as num?)?.toDouble() ??
        (json['discount'] as num?)?.toDouble() ??
        (json['promo_discount_value'] as num?)?.toDouble() ??
        0.0;
    return flatVal;
  }

  static String? _parsePromoDiscountType(dynamic json, dynamic promoData) {
    final activePromo = _getActivePromo(promoData);
    if (activePromo != null) {
      final type = (activePromo['discount_type'] ?? activePromo['type'] ?? activePromo['promo_type'])?.toString();
      if (type != null && type.isNotEmpty) return type;
      if (activePromo['discount_percentage'] != null || activePromo['percentage'] != null) return 'percentage';
    }
    final flatType = (json['discount_type'] ?? json['promo_discount_type'] ?? json['type'])?.toString();
    if (flatType != null && flatType.isNotEmpty) return flatType;
    if (json['discount_percentage'] != null) return 'percentage';
    return 'percentage';
  }

  static Map<String, dynamic>? _getActivePromo(dynamic promoData) {
    if (promoData == null) return null;
    final now = DateTime.now();
    List promos = [];
    if (promoData is List) {
      promos = promoData;
    } else if (promoData is Map) {
      promos = [promoData];
    }
    for (var p in promos) {
      if (p is! Map) continue;
      final isActive = p['is_active'] as bool? ?? true;
      final expiresAtStr = (p['expires_at'] ?? p['end_date'] ?? p['discount_expires_at'])?.toString();
      bool isStillActive = expiresAtStr == null || expiresAtStr.isEmpty
          ? isActive
          : isActive && (DateTime.tryParse(expiresAtStr)?.isAfter(now) ?? true);
      if (isStillActive) return Map<String, dynamic>.from(p);
    }
    return null;
  }

  static bool _parsePromoStatus(dynamic json, dynamic promoData) {
    final active = _getActivePromo(promoData);
    if (active != null) {
      final isActive = active['is_active'] as bool? ?? true;
      final discount = (active['discount_value'] as num?)?.toDouble() ??
          (active['discount_percentage'] as num?)?.toDouble() ??
          (active['discount_amount'] as num?)?.toDouble() ??
          (active['discount'] as num?)?.toDouble() ??
          (active['value'] as num?)?.toDouble() ??
          0.0;
      if (isActive && discount > 0) return true;
    }
    if (json['has_active_promo'] == true ||
        json['has_discount'] == true ||
        json['is_discount_active'] == true) {
      return true;
    }
    final flatDiscount = _parsePromoDiscountValue(json, promoData);
    return flatDiscount > 0;
  }

  static String? _parsePromoTag(dynamic json, dynamic promoData, bool isAr) {
    final activePromo = _getActivePromo(promoData);
    if (activePromo != null) {
      final tag = (isAr
              ? activePromo['tag_ar'] ?? activePromo['title_ar'] ?? activePromo['name_ar'] ?? activePromo['promo_title_ar']
              : activePromo['tag_en'] ?? activePromo['title_en'] ?? activePromo['name_en'] ?? activePromo['promo_title_en'])
          ?.toString() ??
          (activePromo['tag'] ?? activePromo['title'] ?? activePromo['name'])?.toString();
      if (tag != null && tag.isNotEmpty) return tag;
    }
    final flatTag = (isAr
            ? json['tag_ar'] ?? json['promo_tag_ar'] ?? json['title_ar'] ?? json['discount_title_ar']
            : json['tag_en'] ?? json['promo_tag_en'] ?? json['title_en'] ?? json['discount_title_en'])
        ?.toString() ??
        (json['tag'] ?? json['promo_tag'] ?? json['title'] ?? json['discount_title'])?.toString();
    return flatTag;
  }
}
