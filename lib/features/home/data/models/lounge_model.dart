import 'package:equatable/equatable.dart';

class LoungeModel extends Equatable {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String imageUrl;
  final double rating;
  final double distance;
  final double pricePerHour;
  final bool isOpen;
  final String? location;
  final String? city;
  final int? totalReviews;
  final int? availableRooms;
  final String? descriptionAr;
  final String? descriptionEn;
  final List<String> images;
  final String opensAt;
  final String closesAt;
  final String? mapsLink;
  final double? lat;
  final double? lng;
  final List<String> categoryIcons;
  final bool hasDiscount;
  final int discountPercentage;
  final String? discountTitleAr;
  final String? discountTitleEn;
  final DateTime? discountExpiresAt;

  const LoungeModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
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
    required this.opensAt,
    required this.closesAt,
    this.mapsLink,
    this.lat,
    this.lng,
    this.categoryIcons = const [],
    this.hasDiscount = false,
    this.discountPercentage = 0,
    this.discountTitleAr,
    this.discountTitleEn,
    this.discountExpiresAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        nameAr,
        nameEn,
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
        opensAt,
        closesAt,
        mapsLink,
        lat,
        lng,
        categoryIcons,
        hasDiscount,
        discountPercentage,
        discountTitleAr,
        discountTitleEn,
        discountExpiresAt,
      ];

  String getName(bool isArabic) {
    if (isArabic) {
      return (nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;
    } else {
      return (nameEn != null && nameEn!.isNotEmpty) ? nameEn! : name;
    }
  }

  String? getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;
  String? getDiscountTitle(bool isArabic) => isArabic ? discountTitleAr : discountTitleEn;

  bool get isDiscountActive =>
      hasDiscount && (discountExpiresAt == null || discountExpiresAt!.isAfter(DateTime.now()));

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    final double calculatedDistance = (json['distance_km'] as num?)?.toDouble() ??
        (json['distance'] as num?)?.toDouble() ??
        0.0;

    // Safely parse name from 'name', falling back to 'name_ar' or 'name_en'
    final String parsedName = json['name']?.toString() ??
        json['name_ar']?.toString() ??
        json['name_en']?.toString() ??
        '';

    return LoungeModel(
      id: json['id']?.toString() ?? '',
      name: parsedName,
      nameAr: json['name_ar']?.toString() ?? json['name']?.toString(),
      nameEn: json['name_en']?.toString() ?? json['name']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distance: calculatedDistance,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? true,
      location: json['location']?.toString(),
      city: json['city']?.toString(),
      totalReviews: (json['total_reviews'] as num?)?.toInt(),
      availableRooms: (json['available_rooms'] as num?)?.toInt(),
      descriptionAr: json['description_ar']?.toString() ?? json['description']?.toString(),
      descriptionEn: json['description_en']?.toString() ?? json['description']?.toString(),
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      opensAt: json['opening_time']?.toString() ?? json['opens_at']?.toString() ?? '',
      closesAt: json['closing_time']?.toString() ?? json['closes_at']?.toString() ?? '',
      mapsLink: json['maps_link']?.toString(),
      lat: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble(),
      lng: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble(),
      categoryIcons: json['category_icons'] != null ? List<String>.from(json['category_icons']) : [],
      hasDiscount: json['has_discount'] ?? false,
      discountPercentage: (json['discount_percentage'] as num?)?.toInt() ?? 0,
      discountTitleAr: json['discount_title_ar']?.toString(),
      discountTitleEn: json['discount_title_en']?.toString(),
      discountExpiresAt: json['discount_expires_at'] != null ? DateTime.parse(json['discount_expires_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr ?? name,
      'name_en': nameEn ?? name,
      'image_url': imageUrl,
      'rating': rating,
      'distance': distance,
      'price_per_hour': pricePerHour,
      'is_open': isOpen,
      'location': location,
      'city': city,
      'total_reviews': totalReviews,
      'available_rooms': availableRooms,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'images': images,
      'opening_time': opensAt,
      'closing_time': closesAt,
      'maps_link': mapsLink,
      'latitude': lat,
      'longitude': lng,
      'has_discount': hasDiscount,
      'discount_percentage': discountPercentage,
      'discount_title_ar': discountTitleAr,
      'discount_title_en': discountTitleEn,
      'discount_expires_at': discountExpiresAt?.toIso8601String(),
    };
  }
}
