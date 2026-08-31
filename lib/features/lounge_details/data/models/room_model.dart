import 'package:equatable/equatable.dart';

class RoomModel extends Equatable {
  final String id;
  final String loungeId;
  final String nameAr;
  final String nameEn;
  final List<String> activityNames;
  final String? spaceType;
  final String? spaceTypeName;
  final int capacity;
  final double pricePerHour;
  final double pricePerHourSingle;
  final double pricePerHourMulti;
  final double extraControllerPrice;
  final bool isAvailable;
  final List<String> images;
  final List<String> featuresAr;
  final List<String> featuresEn;
  final int controllersCount;
  final String screenSize;

  const RoomModel({
    required this.id,
    required this.loungeId,
    required this.nameAr,
    required this.nameEn,
    required this.activityNames,
    this.spaceType,
    this.spaceTypeName,
    required this.capacity,
    required this.pricePerHour,
    required this.pricePerHourSingle,
    required this.pricePerHourMulti,
    this.extraControllerPrice = 0.0,
    required this.isAvailable,
    required this.images,
    required this.featuresAr,
    required this.featuresEn,
    this.controllersCount = 2,
    this.screenSize = '43"',
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
        capacity,
        pricePerHour,
        pricePerHourSingle,
        pricePerHourMulti,
        extraControllerPrice,
        isAvailable,
        images,
        featuresAr,
        featuresEn,
        controllersCount,
        screenSize,
      ];

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
  List<String> getFeatures(bool isArabic) => isArabic ? featuresAr : featuresEn;

  bool get isVR => activityNames.any((a) => a.toLowerCase().contains('vr'));
  bool get isSimulator => activityNames.any((a) => a.toLowerCase().contains('simulator'));
  bool get isOpenArea => spaceTypeName == 'open_area';
  bool get isVIP => spaceTypeName == 'vip_room';
  bool get isStandard => spaceTypeName == 'standard_room';

  String getDisplayTitle(bool isArabic) {
    if (spaceTypeName == 'open_area') {
      return isArabic ? "شاشة / جهاز ${nameAr}" : "Station / Device ${nameEn}";
    }
    return isArabic ? "غرفة ${nameAr}" : "Room ${nameEn}";
  }

  String spaceTypeLabel(bool isArabic) {
    if (spaceTypeName == 'open_area') return isArabic ? 'صالة مفتوحة' : 'OPEN AREA';
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
      'capacity': capacity,
      'price_per_hour': pricePerHour,
      'price_per_hour_single': pricePerHourSingle,
      'price_per_hour_multi': pricePerHourMulti,
      'extra_controller_price': extraControllerPrice,
      'is_available': isAvailable,
      'images': images,
      'features_ar': featuresAr,
      'features_en': featuresEn,
      'controllers_count': controllersCount,
      'screen_size': screenSize,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    try {
      // Aggregate activity names from the new room_categories join
      final List? roomCats = json['room_categories'] as List?;
      final List<String> activities = [];
      if (roomCats != null) {
        for (var cat in roomCats) {
          if (cat['categories'] != null && cat['categories']['name_en'] != null) {
            activities.add(cat['categories']['name_en']);
          }
        }
      }

      return RoomModel(
        id: json['id']?.toString() ?? '',
        loungeId: json['lounge_id']?.toString() ?? '',
        nameAr: json['name_ar']?.toString() ?? '',
        nameEn: json['name_en']?.toString() ?? '',
        activityNames: activities.isNotEmpty 
            ? activities 
            : (json['activity_names'] != null ? List<String>.from(json['activity_names']) : []),
        spaceType: json['space_type_label'] ?? 
                  (json['space_types'] is List 
                      ? (json['space_types'] as List).isNotEmpty ? (json['space_types'] as List).first['label'] : null
                      : json['space_types']?['label']) ?? 
                  json['space_type_name']?.toString(),
        spaceTypeName: json['space_type_name'] ??
                     (json['space_types'] is List 
                        ? (json['space_types'] as List).isNotEmpty ? (json['space_types'] as List).first['name'] : null
                        : json['space_types']?['name']) ?? 
                     json['space_type_slug']?.toString() ?? 'open_area',
        capacity: (json['capacity'] as num?)?.toInt() ?? 4,
        pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        pricePerHourSingle: (json['price_per_hour_single'] as num?)?.toDouble() ?? (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        pricePerHourMulti: (json['price_per_hour_multi'] as num?)?.toDouble() ?? (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        extraControllerPrice: (json['extra_controller_price'] as num?)?.toDouble() ?? 0.0,
        isAvailable: json['is_available'] ?? true,
        images: json['images'] != null ? List<String>.from(json['images']) : [],
        featuresAr: json['features_ar'] != null ? List<String>.from(json['features_ar']) : [],
        featuresEn: json['features_en'] != null ? List<String>.from(json['features_en']) : [],
        controllersCount: (json['controllers_count'] as num?)?.toInt() ?? 2,
        screenSize: json['screen_size']?.toString() ?? '43"',
      );
    } catch (e) {
      print("Error parsing RoomModel: $e");
      rethrow;
    }
  }
}
