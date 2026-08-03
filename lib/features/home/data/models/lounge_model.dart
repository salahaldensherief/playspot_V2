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
  final List<String>? images;
  final String opensAt;
  final String closesAt;

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
    this.images,
    required this.opensAt,
    required this.closesAt,
  });

  String? getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    // Handling distance conversion from meters (RPC) or double (normal)
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
      // price_per_hour might be missing in RPC, defaulting to 0 or handling null
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? true,
      location: json['location']?.toString(),
      city: json['city']?.toString(),
      totalReviews: (json['total_reviews'] as num?)?.toInt(),
      availableRooms: (json['available_rooms'] as num?)?.toInt(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      opensAt: json['opens_at']?.toString() ?? '',
      closesAt: json['closes_at']?.toString() ?? '',
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
    };
  }
}
