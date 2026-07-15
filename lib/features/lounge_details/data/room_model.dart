class RoomModel {
  final String id;
  final String loungeId;
  final String name;
  final List<String> activityNames; // بدل type - روم واحد ممكن يبقى فيه أكتر من نشاط
  final String? spaceType; // 'open' / 'private' / 'vip'
  final int capacity;
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
    required this.activityNames,
    this.spaceType,
    this.capacity = 4,
    required this.pricePerHour,
    required this.isAvailable,
    required this.images,
    required this.features,
    this.controllersCount = 2,
    this.screenSize = '43"',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lounge_id': loungeId,
      'name': name,
      'activity_names': activityNames,
      'space_type_name': spaceType,
      'capacity': capacity,
      'price_per_hour': pricePerHour,
      'is_available': isAvailable,
      'images': images,
      'features': features,
      'controllers_count': controllersCount,
      'screen_size': screenSize,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    try {
      return RoomModel(
        id: json['id']?.toString() ?? '',
        loungeId: json['lounge_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        activityNames: json['activity_names'] != null
            ? List<String>.from(json['activity_names'])
            : (json['type'] != null ? [json['type'].toString()] : []),
        spaceType: json['space_type_name']?.toString(),
        capacity: (json['capacity'] as num?)?.toInt() ?? 4,
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
