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
    try {
      return RoomModel(
        id: json['id']?.toString() ?? '',
        loungeId: json['lounge_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        isAvailable: json['is_available'] ?? true,
        images: json['images'] != null ? List<String>.from(json['images']) : [],
        features: json['features'] != null ? List<String>.from(json['features']) : [],
        controllersCount: (json['controllers_count'] as num?)?.toInt() ?? 2,
        screenSize: json['screen_size']?.toString() ?? '43"',
      );
    } catch (e) {
      print("Error parsing RoomModel: $e");
      rethrow;
    }
  }
}
