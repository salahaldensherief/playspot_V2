import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class PromoModel extends Equatable {
  final String id;
  final String titleAr;
  final String titleEn;
  final String tagAr;
  final String tagEn;
  final List<String> hexColors;
  final String iconKey;
  final String? imageUrl;
  final String? deepLink;
  final String? loungeId;
  final String? roomId;
  final bool isRoomSpecific;
  final DateTime? expiresAt;

  const PromoModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.tagAr,
    required this.tagEn,
    required this.hexColors,
    required this.iconKey,
    this.imageUrl,
    this.deepLink,
    this.loungeId,
    this.roomId,
    this.isRoomSpecific = false,
    this.expiresAt,
  });

  @override
  List<Object?> get props => [
        id,
        titleAr,
        titleEn,
        tagAr,
        tagEn,
        hexColors,
        iconKey,
        imageUrl,
        deepLink,
        loungeId,
        roomId,
        isRoomSpecific,
        expiresAt,
      ];

  String getTitle(bool isArabic) => isArabic ? titleAr : titleEn;
  String getTag(bool isArabic) => isArabic ? tagAr : tagEn;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  List<Color> get colors {
// ... existing colors getter logic ...
    if (hexColors.isEmpty) {
      return [const Color(0xFF00F2FE), const Color(0xFF4FACFE)]; // Default gradient
    }
    final mappedColors = hexColors.map((hex) {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    }).toList();

    if (mappedColors.length == 1) {
      // If only one color is provided, create a gradient with a darker version of it
      return [mappedColors[0], mappedColors[0].withValues(alpha: 0.8)];
    }
    return mappedColors;
  }

  IconData get icon {
// ... existing icon getter logic ...
    switch (iconKey) {
      case 'videogame_asset':
        return Icons.videogame_asset;
      case 'computer':
        return Icons.computer;
      case 'local_offer':
        return Icons.local_offer;
      case 'celebration':
        return Icons.celebration;
      case 'stars':
        return Icons.stars;
      case 'flash_on':
        return Icons.flash_on;
      case 'sports_esports':
        return Icons.sports_esports;
      default:
        return Icons.auto_awesome;
    }
  }

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    String? rawRoomId = (json['room_id'] ?? json['roomId'] ?? json['target_room_id'])?.toString();
    String? rawLoungeId = (json['lounge_id'] ?? json['loungeId'] ?? json['target_lounge_id'])?.toString();
    final deepLinkStr = (json['deep_link'] ?? json['deepLink'])?.toString();

    // Extract UUID from deepLink if room_id is not directly provided
    if ((rawRoomId == null || rawRoomId.isEmpty) && deepLinkStr != null && deepLinkStr.isNotEmpty) {
      final uuidRegex = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
      final match = uuidRegex.firstMatch(deepLinkStr);
      if (match != null && (deepLinkStr.contains('room') || deepLinkStr.contains('Specific'))) {
        rawRoomId = match.group(0);
      }
    }

    final isRoomSpecific = (json['is_room_specific'] as bool?) ??
        (rawRoomId != null && rawRoomId.isNotEmpty);

    return PromoModel(
      id: json['id']?.toString() ?? json['promotion_id']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? json['title']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? json['title']?.toString() ?? '',
      tagAr: json['tag_ar']?.toString() ?? json['tag']?.toString() ?? '',
      tagEn: json['tag_en']?.toString() ?? json['tag']?.toString() ?? '',
      hexColors: List<String>.from(json['colors'] ?? []),
      iconKey: json['icon_key']?.toString() ?? '',
      imageUrl: (json['image_url'] ?? json['image'] ?? json['imageUrl'] ?? json['banner'])?.toString(),
      deepLink: deepLinkStr,
      loungeId: rawLoungeId,
      roomId: rawRoomId,
      isRoomSpecific: isRoomSpecific,
      expiresAt: (json['expires_at'] ?? json['end_date']) != null
          ? DateTime.tryParse((json['expires_at'] ?? json['end_date']).toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title_ar': titleAr,
      'title_en': titleEn,
      'tag_ar': tagAr,
      'tag_en': tagEn,
      'colors': hexColors,
      'icon_key': iconKey,
      'image_url': imageUrl,
      'deep_link': deepLink,
      'lounge_id': loungeId,
      'room_id': roomId,
      'is_room_specific': isRoomSpecific,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}

