class LoungeModel {
  final String id;
  final String name;
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

  LoungeModel({
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
    required this.opensAt,
    required this.closesAt,
    this.mapsLink,
    this.lat,
    this.lng,
    this.categoryIcons = const [],
  });

  String? getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    double calculatedDistance = 0.0;
    if (json['dist_meters'] != null) {
      calculatedDistance = (json['dist_meters'] as num).toDouble() / 1000.0;
    } else if (json['distance'] != null) {
      calculatedDistance = (json['distance'] as num).toDouble();
    }

    return LoungeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distance: calculatedDistance,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? true,
      location: json['location']?.toString(),
      city: json['city']?.toString(),
      totalReviews: (json['total_reviews'] as num?)?.toInt(),
      availableRooms: (json['available_rooms'] as num?)?.toInt(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      opensAt: json['opens_at']?.toString() ?? '',
      closesAt: json['closes_at']?.toString() ?? '',
      mapsLink: json['maps_link']?.toString(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      categoryIcons: json['category_icons'] != null ? List<String>.from(json['category_icons']) : [],
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
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'images': images,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'maps_link': mapsLink,
      'lat': lat,
      'lng': lng,
    };
  }
}
