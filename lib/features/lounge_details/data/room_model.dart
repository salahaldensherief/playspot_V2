class RoomModel {
  final String id;
  final String loungeId;
  final String name;
  final String type; // VIP, Standard, etc.
  final double pricePerHour;
  final bool isAvailable;
  final List<String> images;
  final List<String> features;
  final int controllersCount;
  final String screenSize;

  RoomModel({
    required this.id,
    required this.loungeId,
    required this.name,
    required this.type,
    required this.pricePerHour,
    required this.isAvailable,
    required this.images,
    required this.features,
    this.controllersCount = 2,
    this.screenSize = '43"',
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'].toString(),
      loungeId: json['lounge_id'].toString(),
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['is_available'] ?? true,
      images: List<String>.from(json['images'] ?? []),
      features: List<String>.from(json['features'] ?? []),
      controllersCount: json['controllers_count'] ?? 2,
      screenSize: json['screen_size'] ?? '43"',
    );
  }
}
