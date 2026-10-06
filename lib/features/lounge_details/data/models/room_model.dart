import 'package:equatable/equatable.dart';
import 'room_json_decoder.dart';

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
  final bool requiresScreen;
  final bool requiresControllers;
  final String pricingModel;
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
    this.controllersCount = 0,
    this.screenSize = '',
    this.requiresScreen = true,
    this.requiresControllers = true,
    this.pricingModel = 'single_multi_hour',
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
    requiresScreen,
    requiresControllers,
    pricingModel,
    hasActivePromo,
    promoTagAr,
    promoTagEn,
    promoDiscountValue,
    promoDiscountType,
  ];

  String getName(bool isArabic) => isArabic
      ? (nameAr.isEmpty ? nameEn : nameAr)
      : (nameEn.isEmpty ? nameAr : nameEn);
  List<String> getFeatures(bool isArabic) {
    final primary = isArabic ? featuresAr : featuresEn;
    final fallback = isArabic ? featuresEn : featuresAr;
    return (primary.isEmpty ? fallback : primary)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  String? getPromoTag(bool isArabic) => isArabic ? promoTagAr : promoTagEn;

  int get capacity => maxCapacity;
  double get hourlyRate => hourlyRateSingle;

  double get effectivePrice => effectivePriceSingle;

  double get effectivePriceSingle {
    if (!hasActivePromo || promoDiscountValue <= 0) return hourlyRateSingle;

    if (promoDiscountType == 'percentage') {
      return hourlyRateSingle * (1 - (promoDiscountValue / 100));
    } else if (promoDiscountType == 'fixed') {
      return (hourlyRateSingle - promoDiscountValue).clamp(
        0.0,
        double.infinity,
      );
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

  double calculateEffectiveRate({
    required String playMode,
    int extraControllers = 0,
    double loungeDiscountPercentage = 0,
  }) {
    final base = (isOpenArea && playMode == 'multi')
        ? hourlyRateMulti
        : hourlyRateSingle;

    double discounted = base;
    if (hasActivePromo && promoDiscountValue > 0) {
      if (promoDiscountType == 'percentage') {
        discounted = base * (1 - (promoDiscountValue / 100));
      } else if (promoDiscountType == 'fixed') {
        discounted = (base - promoDiscountValue).clamp(0.0, double.infinity);
      }
    } else if (loungeDiscountPercentage > 0) {
      discounted = base * (1 - (loungeDiscountPercentage / 100));
    }

    return discounted + (extraControllers * extraControllerPrice);
  }

  double calculateOriginalRate({
    required String playMode,
    int extraControllers = 0,
  }) {
    final base = (isOpenArea && playMode == 'multi')
        ? hourlyRateMulti
        : hourlyRateSingle;
    return base + (extraControllers * extraControllerPrice);
  }

  bool get hasExpandableDetails =>
      activityNames.isNotEmpty ||
      images.isNotEmpty ||
      getFeatures(true).isNotEmpty ||
      getFeatures(false).isNotEmpty ||
      isOpenArea ||
      extraControllerPrice > 0;

  bool get isVR => activityNames.any((a) => a.toLowerCase().contains('vr'));
  bool get isSimulator =>
      activityNames.any((a) => a.toLowerCase().contains('simulator'));
  bool get isOpenArea => spaceTypeName == 'open_area';
  bool get isVIP => spaceTypeName == 'vip_room';
  bool get isStandard => spaceTypeName == 'standard_room';
  bool get isOccupied => status.trim().toLowerCase() == 'occupied';
  bool get supportsPlayModePricing => pricingModel == 'single_multi_hour';

  String getDisplayTitle(bool isArabic) => getName(isArabic);

  String spaceTypeLabel(bool isArabic) {
    if (spaceTypeName == 'open_area') {
      return isArabic ? 'صالة مفتوحة' : 'OPEN AREA';
    }
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
      'requires_screen': requiresScreen,
      'requires_controllers': requiresControllers,
      'pricing_model': pricingModel,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) =>
      RoomJsonDecoder(json).decode();
}
