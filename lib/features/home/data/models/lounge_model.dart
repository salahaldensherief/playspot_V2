import 'package:equatable/equatable.dart';

class LoungeModel extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final double distance; // Stored in kilometers
  final double pricePerHour;
  final bool isOpen;
  final String? location;
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
    required this.pricePerHour,
    required this.isOpen,
    this.location,
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
  String? get address => location;

  String? get effectiveWalletNumber =>
      walletNumber ?? vodafoneCashNumber;

  String? get effectiveInstapayHandle =>
      instapayHandle ?? instaPayAccount;

  @override
  List<Object?> get props => [
        id,
        name,
        imageUrl,
        rating,
        distance,
        pricePerHour,
        isOpen,
        location,
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

  String getName(bool isArabic) => name;

  String? getDescription(bool isArabic) =>
      (isArabic ? descriptionAr : descriptionEn) ?? descriptionAr ?? descriptionEn;

  String? getDiscountTitle(bool isArabic) => isArabic ? discountTitleAr : discountTitleEn;

  bool get isDiscountActive =>
      hasDiscount && (discountExpiresAt == null || discountExpiresAt!.isAfter(DateTime.now()));

  /// Formats distance presentation logic:
  /// - Handles safety checks for 0 or >= 99999 (unknown/invalid) gracefully.
  /// - If distance >= 1.0 km (>= 1000m), formats to 1 decimal place followed by 'km' (e.g., 11.9 km / 11.9 كم).
  /// - If distance < 1.0 km (< 1000m), formats as meters followed by 'm' (e.g., 850 m / 850 م).
  String getFormattedDistance({required bool isArabic}) {
    if (distance <= 0 || distance >= 99999) return '';

    final double meters = distance >= 100 ? distance : distance * 1000.0;

    if (meters >= 1000) {
      final double km = meters / 1000.0;
      final String unit = isArabic ? 'كم' : 'km';
      return '${km.toStringAsFixed(1)} $unit';
    } else {
      final String unit = isArabic ? 'م' : 'm';
      return '${meters.toInt()} $unit';
    }
  }

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    // 1. Distance Calculation (Normalizes distance in km)
    double rawDistance = (json['distance_km'] as num?)?.toDouble() ??
        (json['distance_in_km'] as num?)?.toDouble() ??
        (json['distance'] as num?)?.toDouble() ??
        0.0;

    // Convert raw meters to kilometers if value is large (>100)
    if (json['distance_km'] == null && json['distance_in_km'] == null && rawDistance >= 100) {
      rawDistance = rawDistance / 1000.0;
    }

    // 2. Name
    final String parsedName = json['name']?.toString() ?? '';

    // 3. Price Per Hour Fallback
    final double parsedPricePerHour = (json['price_per_hour'] as num?)?.toDouble() ??
        (json['hourly_rate'] as num?)?.toDouble() ??
        (json['hourly_price'] as num?)?.toDouble() ??
        (json['rate_per_hour'] as num?)?.toDouble() ??
        (json['price_per_hr'] as num?)?.toDouble() ??
        (json['hourly_fee'] as num?)?.toDouble() ??
        (json['min_price_per_hour'] as num?)?.toDouble() ??
        (json['min_price'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        80.0;

    // 4. Rating Fallback
    final double parsedRating = (json['rating'] as num?)?.toDouble() ??
        (json['avg_rating'] as num?)?.toDouble() ??
        (json['average_rating'] as num?)?.toDouble() ??
        0.0;

    // 5. Category Icons
    List<String> parsedCategoryIcons = [];
    if (json['category_icons'] != null) {
      parsedCategoryIcons = List<String>.from(json['category_icons'].map((e) => e.toString()));
    } else if (json['categories'] != null && json['categories'] is List) {
      parsedCategoryIcons = (json['categories'] as List)
          .map((e) => e is Map ? (e['icon'] ?? e['key'] ?? e['icon_key'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // 6. Gallery Images
    List<String> parsedImages = [];
    if (json['images'] != null) {
      parsedImages = List<String>.from(json['images'].map((e) => e.toString()));
    } else if (json['gallery'] != null) {
      parsedImages = List<String>.from(json['gallery'].map((e) => e.toString()));
    }

    // 7. Discount & Promotions Parsing (Supports promotions join, active_promotion map, or flat discount fields)
    int parsedDiscountPercentage = (json['discount_percentage'] as num?)?.toInt() ??
        (json['discount_value'] as num?)?.toInt() ??
        (json['discount'] as num?)?.toInt() ??
        0;

    String? parsedDiscountTitleAr = json['discount_title_ar']?.toString() ??
        json['promo_title_ar']?.toString() ??
        json['tag_ar']?.toString() ??
        json['title_ar']?.toString();

    String? parsedDiscountTitleEn = json['discount_title_en']?.toString() ??
        json['promo_title_en']?.toString() ??
        json['tag_en']?.toString() ??
        json['title_en']?.toString();

    DateTime? parsedDiscountExpiresAt;
    if (json['discount_expires_at'] != null || json['expires_at'] != null) {
      try {
        parsedDiscountExpiresAt = DateTime.parse((json['discount_expires_at'] ?? json['expires_at']).toString());
      } catch (_) {}
    }

    final promoData = json['promotions'] ??
        json['active_promotion'] ??
        json['promotion'] ??
        json['active_promo'] ??
        json['promo'];

    if (promoData != null) {
      final now = DateTime.now();
      List promos = promoData is List ? promoData : (promoData is Map ? [promoData] : []);
      for (var p in promos) {
        if (p is! Map) continue;
        final isActive = p['is_active'] as bool? ?? true;
        final expStr = (p['expires_at'] ?? p['end_date'] ?? p['discount_expires_at'])?.toString();
        bool isStillActive = expStr == null || expStr.isEmpty
            ? isActive
            : isActive && (DateTime.tryParse(expStr)?.isAfter(now) ?? true);
        if (isStillActive) {
          final discVal = (p['discount_percentage'] as num?)?.toInt() ??
              (p['discount_value'] as num?)?.toInt() ??
              (p['discount'] as num?)?.toInt() ??
              0;
          if (discVal > 0) parsedDiscountPercentage = discVal;
          parsedDiscountTitleAr ??= p['tag_ar']?.toString() ?? p['title_ar']?.toString() ?? p['tag']?.toString() ?? p['title']?.toString();
          parsedDiscountTitleEn ??= p['tag_en']?.toString() ?? p['title_en']?.toString() ?? p['tag']?.toString() ?? p['title']?.toString();
          if (expStr != null && expStr.isNotEmpty) {
            try { parsedDiscountExpiresAt = DateTime.parse(expStr); } catch (_) {}
          }
          break;
        }
      }
    }

    final bool parsedHasDiscount = json['has_discount'] == true ||
        json['is_discount_active'] == true ||
        json['has_active_promo'] == true ||
        parsedDiscountPercentage > 0 ||
        (parsedDiscountTitleAr != null && parsedDiscountTitleAr.isNotEmpty);

    // 8. Spatial Location parsing from location_point (PostGIS) or flat RPC fields
    double? parsedLat = (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble();
    double? parsedLng = (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble();

    if (parsedLat == null && json['location_point'] != null) {
      final loc = json['location_point'];
      if (loc is Map && loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        parsedLng = (loc['coordinates'][0] as num).toDouble();
        parsedLat = (loc['coordinates'][1] as num).toDouble();
      }
    }

    final int? parsedTotalReviews = (json['total_reviews'] as num?)?.toInt() ??
        (json['reviews_count'] as num?)?.toInt() ??
        (json['review_count'] as num?)?.toInt() ??
        (json['total_review'] as num?)?.toInt() ??
        (json['num_reviews'] as num?)?.toInt() ??
        (json['ratings_count'] as num?)?.toInt() ??
        ((json['lounge_reviews'] is List) ? (json['lounge_reviews'] as List).length : null) ??
        ((json['reviews'] is List) ? (json['reviews'] as List).length : null);

    return LoungeModel(
      id: json['id']?.toString() ?? '',
      name: parsedName,
      imageUrl: json['image_url']?.toString() ?? '',
      rating: parsedRating,
      distance: rawDistance,
      pricePerHour: parsedPricePerHour,
      isOpen: json['is_open'] as bool? ?? true,
      location: json['location']?.toString() ?? json['address']?.toString(),
      city: json['city']?.toString() ?? json['city_name']?.toString(),
      totalReviews: parsedTotalReviews,
      availableRooms: (json['available_rooms'] as num?)?.toInt() ?? (json['rooms_count'] as num?)?.toInt(),
      descriptionAr: json['description_ar']?.toString() ?? json['description']?.toString(),
      descriptionEn: json['description_en']?.toString() ?? json['description']?.toString(),
      images: parsedImages,
      openingTime: json['opening_time']?.toString() ?? '',
      closingTime: json['closing_time']?.toString() ?? '',
      mapsLink: json['maps_link']?.toString(),
      lat: parsedLat,
      lng: parsedLng,
      categoryIcons: parsedCategoryIcons,
      hasDiscount: parsedHasDiscount,
      discountPercentage: parsedDiscountPercentage,
      discountTitleAr: parsedDiscountTitleAr,
      discountTitleEn: parsedDiscountTitleEn,
      discountExpiresAt: parsedDiscountExpiresAt,
      status: json['status']?.toString() ?? 'active',
      isActive: json['is_active'] as bool? ?? true,
      vodafoneCashNumber: json['vodafone_cash_number']?.toString().trim(),
      instaPayAccount: json['instapay_account']?.toString().trim() ?? json['insta_pay_account']?.toString().trim(),
      walletNumber: json['wallet_number']?.toString().trim() ?? json['vodafone_cash_number']?.toString().trim(),
      instapayHandle: json['instapay_handle']?.toString().trim() ?? json['instapay_account']?.toString().trim() ?? json['insta_pay_account']?.toString().trim(),
      allowCashPayment: json['allow_cash_payment'] as bool? ?? json['allow_cash'] as bool? ?? true,
      requirePrepaidFirstTime: json['require_prepaid_first_time'] as bool? ?? json['require_prepaid'] as bool? ?? false,
      cashGracePeriodMinutes: (json['cash_grace_period_minutes'] as num?)?.toInt() ??
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
      'distance': distance,
      'price_per_hour': pricePerHour,
      'is_open': isOpen,
      'location': location,
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
      if (vodafoneCashNumber != null) 'vodafone_cash_number': vodafoneCashNumber,
      if (instaPayAccount != null) 'instapay_account': instaPayAccount,
      if (walletNumber != null) 'wallet_number': walletNumber,
      if (instapayHandle != null) 'instapay_handle': instapayHandle,
      'allow_cash_payment': allowCashPayment,
      'require_prepaid_first_time': requirePrepaidFirstTime,
      'cash_grace_period_minutes': cashGracePeriodMinutes,
    };
  }
}
