import 'package:equatable/equatable.dart';

class RoomModel extends Equatable {
  final String id;
  final String loungeId;
  final String nameAr;
  final String nameEn;
  final List<String> activityNames;
  final String? spaceType;
  final String? spaceTypeName;
  final int capacity;
  final double pricePerHour;
  final double pricePerHourSingle;
  final double pricePerHourMulti;
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
    required this.capacity,
    required this.pricePerHour,
    required this.pricePerHourSingle,
    required this.pricePerHourMulti,
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
    capacity,
    pricePerHour,
    pricePerHourSingle,
    pricePerHourMulti,
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

  double get effectivePrice {
    if (!hasActivePromo || promoDiscountValue <= 0) return pricePerHour;

    if (promoDiscountType == 'percentage') {
      return pricePerHour * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (pricePerHour - promoDiscountValue).clamp(0.0, double.infinity);
    }
    return pricePerHour;
  }

  double get effectivePriceSingle {
    if (!hasActivePromo || promoDiscountValue <= 0) return pricePerHourSingle;

    if (promoDiscountType == 'percentage') {
      return pricePerHourSingle * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (pricePerHourSingle - promoDiscountValue).clamp(0.0, double.infinity);
    }
    return pricePerHourSingle;
  }

  double get effectivePriceMulti {
    if (!hasActivePromo || promoDiscountValue <= 0) return pricePerHourMulti;

    if (promoDiscountType == 'percentage') {
      return pricePerHourMulti * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (pricePerHourMulti - promoDiscountValue).clamp(0.0, double.infinity);
    }
    return pricePerHourMulti;
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
      'capacity': capacity,
      'price_per_hour': pricePerHour,
      'price_per_hour_single': pricePerHourSingle,
      'price_per_hour_multi': pricePerHourMulti,
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
        capacity: (json['capacity'] as num?)?.toInt() ?? 4,
        pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        pricePerHourSingle: (json['price_per_hour_single'] as num?)?.toDouble() ?? (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        pricePerHourMulti: (json['price_per_hour_multi'] as num?)?.toDouble() ?? (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        extraControllerPrice: (json['extra_controller_price'] as num?)?.toDouble() ?? 0.0,
        isAvailable: json['is_available'] ?? true,
        status: json['status']?.toString() ?? 'available',
        images: json['images'] != null ? List<String>.from(json['images']) : [],
        featuresAr: json['features_ar'] != null ? List<String>.from(json['features_ar']) : [],
        featuresEn: json['features_en'] != null ? List<String>.from(json['features_en']) : [],
        controllersCount: (json['controllers_count'] as num?)?.toInt() ?? 2,
        screenSize: json['screen_size']?.toString() ?? '43"',
        hasActivePromo: _parsePromoStatus(json['promotions'] as List?),
        promoTagAr: _parsePromoTag(json['promotions'] as List?, true),
        promoTagEn: _parsePromoTag(json['promotions'] as List?, false),
        promoDiscountValue: _parsePromoDiscountValue(json['promotions'] as List?),
        promoDiscountType: _parsePromoDiscountType(json['promotions'] as List?),
      );
    } catch (e) {
      print("Error parsing RoomModel: $e");
      rethrow;
    }
  }

  static double _parsePromoDiscountValue(List? promos) {
    if (promos == null || promos.isEmpty) return 0.0;
    final activePromo = _getActivePromo(promos);
    return (activePromo?['discount_value'] as num?)?.toDouble() ?? 0.0;
  }

  static String? _parsePromoDiscountType(List? promos) {
    if (promos == null || promos.isEmpty) return null;
    final activePromo = _getActivePromo(promos);
    return activePromo?['discount_type']?.toString();
  }

  static Map<String, dynamic>? _getActivePromo(List promos) {
    final now = DateTime.now();
    for (var p in promos) {
      final isActive = p['is_active'] as bool? ?? false;
      final expiresAtStr = p['expires_at']?.toString();
      bool isStillActive = expiresAtStr == null ? isActive : isActive && DateTime.parse(expiresAtStr).isAfter(now);
      if (isStillActive) return Map<String, dynamic>.from(p);
    }
    return null;
  }

  static bool _parsePromoStatus(List? promos) {
    final active = _getActivePromo(promos ?? []);
    if (active == null) return false;
    final discount = (active['discount_value'] as num?)?.toDouble() ?? 0.0;
    return discount > 0;
  }

  static String? _parsePromoTag(List? promos, bool isAr) {
    final activePromo = _getActivePromo(promos ?? []);
    if (activePromo == null) return null;
    return (isAr ? activePromo['tag_ar'] : activePromo['tag_en'])?.toString() ?? activePromo['tag']?.toString();
  }
}