import 'package:equatable/equatable.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import 'lounge_distance.dart';
import 'lounge_json_decoder.dart';

class LoungeModel extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final double distance; // Stored in kilometers
  final bool distanceIsApproximate;
  final double pricePerHour;
  final bool isOpen;
  final String? contactPhone;
  final String? location;
  final String? streetAddress;
  final String? city;
  final int? totalReviews;
  final int? availableRooms;
  final String? descriptionAr;
  final String? descriptionEn;
  final List<String> images;
  final String openingTime;
  final String closingTime;
  final String? mapsLink;
  final double? lat;
  final double? lng;
  final List<String> categoryIcons;
  final bool hasDiscount;
  final int discountPercentage;
  final String? discountTitleAr;
  final String? discountTitleEn;
  final DateTime? discountExpiresAt;
  final String status;
  final bool isActive;
  final String? vodafoneCashNumber;
  final String? instaPayAccount;
  final String? walletNumber;
  final String? instapayHandle;
  final bool allowCashPayment;
  final bool requirePrepaidFirstTime;
  final int cashGracePeriodMinutes;

  const LoungeModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.distance,
    this.distanceIsApproximate = false,
    required this.pricePerHour,
    required this.isOpen,
    this.contactPhone,
    this.location,
    this.streetAddress,
    this.city,
    this.totalReviews,
    this.availableRooms,
    this.descriptionAr,
    this.descriptionEn,
    this.images = const [],
    required this.openingTime,
    required this.closingTime,
    this.mapsLink,
    this.lat,
    this.lng,
    this.categoryIcons = const [],
    this.hasDiscount = false,
    this.discountPercentage = 0,
    this.discountTitleAr,
    this.discountTitleEn,
    this.discountExpiresAt,
    this.status = 'active',
    this.isActive = true,
    this.vodafoneCashNumber,
    this.instaPayAccount,
    this.walletNumber,
    this.instapayHandle,
    this.allowCashPayment = true,
    this.requirePrepaidFirstTime = false,
    this.cashGracePeriodMinutes = 10,
  });

  String get opensAt => openingTime;
  String get closesAt => closingTime;
  String? get address =>
      (streetAddress?.trim().isNotEmpty ?? false) ? streetAddress : location;

  String? get effectiveWalletNumber => walletNumber ?? vodafoneCashNumber;

  String? get effectiveInstapayHandle => instapayHandle ?? instaPayAccount;

  @override
  List<Object?> get props => [
    id,
    name,
    imageUrl,
    rating,
    distance,
    distanceIsApproximate,
    pricePerHour,
    isOpen,
    contactPhone,
    location,
    streetAddress,
    city,
    totalReviews,
    availableRooms,
    descriptionAr,
    descriptionEn,
    images,
    openingTime,
    closingTime,
    mapsLink,
    lat,
    lng,
    categoryIcons,
    hasDiscount,
    discountPercentage,
    discountTitleAr,
    discountTitleEn,
    discountExpiresAt,
    status,
    isActive,
    vodafoneCashNumber,
    instaPayAccount,
    walletNumber,
    instapayHandle,
    allowCashPayment,
    requirePrepaidFirstTime,
    cashGracePeriodMinutes,
  ];

  List<String> get galleryImages => [imageUrl, ...images]
      .map((image) => image.trim())
      .where((image) => image.isNotEmpty)
      .toSet()
      .toList();

  String getName(bool isArabic) => name;

  String? getDescription(bool isArabic) =>
      (isArabic ? descriptionAr : descriptionEn) ??
      descriptionAr ??
      descriptionEn;

  String? getDiscountTitle(bool isArabic) =>
      isArabic ? discountTitleAr : discountTitleEn;

  bool get isDiscountActive =>
      hasDiscount &&
      (discountExpiresAt == null || discountExpiresAt!.isAfter(DateTime.now()));

  String getFormattedDistance({required bool isArabic}) {
    final formatted = LoungeDistance.format(distance, isArabic: isArabic);
    return distanceIsApproximate && formatted.isNotEmpty
        ? '≈ $formatted'
        : formatted;
  }

  LoungeModel withDistanceEstimate(double? kilometers) => LoungeModel.fromJson({
    ...toJson(),
    'distance_km': kilometers,
    'distance_is_approximate': kilometers != null,
  });

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    final decoder = LoungeJsonDecoder(json);
    final point = GeoCoordinates.fromJson(json);
    return LoungeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      rating: decoder.rating,
      distance: LoungeDistance.fromJson(json),
      distanceIsApproximate: json['distance_is_approximate'] == true,
      pricePerHour: decoder.pricePerHour,
      isOpen: json['is_open'] as bool? ?? true,
      contactPhone: json['contact_phone']?.toString().trim(),
      location: json['location']?.toString() ?? json['address']?.toString(),
      streetAddress: json['address']?.toString(),
      city: json['city']?.toString() ?? json['city_name']?.toString(),
      totalReviews: decoder.totalReviews,
      availableRooms:
          (json['available_rooms'] as num?)?.toInt() ??
          (json['rooms_count'] as num?)?.toInt(),
      descriptionAr:
          json['description_ar']?.toString() ?? json['description']?.toString(),
      descriptionEn:
          json['description_en']?.toString() ?? json['description']?.toString(),
      images: decoder.images,
      openingTime: json['opening_time']?.toString() ?? '',
      closingTime: json['closing_time']?.toString() ?? '',
      mapsLink: json['maps_link']?.toString(),
      lat: point?.latitude,
      lng: point?.longitude,
      categoryIcons: decoder.categoryIcons,
      hasDiscount: decoder.promotion.hasDiscount,
      discountPercentage: decoder.promotion.percentage,
      discountTitleAr: decoder.promotion.title('ar'),
      discountTitleEn: decoder.promotion.title('en'),
      discountExpiresAt: decoder.promotion.expiresAt,
      status: json['status']?.toString() ?? 'active',
      isActive: json['is_active'] as bool? ?? true,
      vodafoneCashNumber: json['vodafone_cash_number']?.toString().trim(),
      instaPayAccount:
          json['instapay_account']?.toString().trim() ??
          json['insta_pay_account']?.toString().trim(),
      walletNumber:
          json['wallet_number']?.toString().trim() ??
          json['vodafone_cash_number']?.toString().trim(),
      instapayHandle:
          json['instapay_handle']?.toString().trim() ??
          json['instapay_account']?.toString().trim() ??
          json['insta_pay_account']?.toString().trim(),
      allowCashPayment:
          json['allow_cash_payment'] as bool? ??
          json['allow_cash'] as bool? ??
          true,
      requirePrepaidFirstTime:
          json['require_prepaid_first_time'] as bool? ??
          json['require_prepaid'] as bool? ??
          false,
      cashGracePeriodMinutes:
          (json['cash_grace_period_minutes'] as num?)?.toInt() ??
          (json['cancellation_grace_period_minutes'] as num?)?.toInt() ??
          (json['grace_period_minutes'] as num?)?.toInt() ??
          10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'rating': rating,
      'distance_km': distance.isFinite ? distance : null,
      'distance_is_approximate': distanceIsApproximate,
      'latitude': lat,
      'longitude': lng,
      'category_icons': categoryIcons,
      'price_per_hour': pricePerHour,
      'is_open': isOpen,
      if (contactPhone != null) 'contact_phone': contactPhone,
      'location': location,
      'address': streetAddress,
      'city': city,
      'total_reviews': totalReviews,
      'available_rooms': availableRooms,
      if (descriptionAr != null) 'description_ar': descriptionAr,
      if (descriptionEn != null) 'description_en': descriptionEn,
      'images': images,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'maps_link': mapsLink,
      'has_discount': hasDiscount,
      'discount_percentage': discountPercentage,
      if (discountTitleAr != null) 'discount_title_ar': discountTitleAr,
      if (discountTitleEn != null) 'discount_title_en': discountTitleEn,
      'discount_expires_at': discountExpiresAt?.toIso8601String(),
      'status': status,
      'is_active': isActive,
      if (vodafoneCashNumber != null)
        'vodafone_cash_number': vodafoneCashNumber,
      if (instaPayAccount != null) 'instapay_account': instaPayAccount,
      if (walletNumber != null) 'wallet_number': walletNumber,
      if (instapayHandle != null) 'instapay_handle': instapayHandle,
      'allow_cash_payment': allowCashPayment,
      'require_prepaid_first_time': requirePrepaidFirstTime,
      'cash_grace_period_minutes': cashGracePeriodMinutes,
    };
  }
}
