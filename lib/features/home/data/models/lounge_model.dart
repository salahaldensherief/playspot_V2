class LoungeModel {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final double distance;
  final double pricePerHour;
  final bool isOpen;
  final String? location;
  final int? availableRooms;
  final String? description;
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
    this.availableRooms,
    this.description,
    this.images,
    required this.opensAt,
    required this.closesAt,
  });

  factory LoungeModel.fromJson(Map<String, dynamic> json) {
    return LoungeModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? true,
      location: json['location'],
      availableRooms: json['available_rooms'],
      description: json['description'],
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      opensAt: json['opens_at'],
      closesAt: json['closes_at'],
    );
  }
}
