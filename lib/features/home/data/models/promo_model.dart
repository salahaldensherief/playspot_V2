import '../../../../art_core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PromoModel {
  final String id;
  final String title;
  final String tag;
  final List<String> hexColors;
  final String iconKey;
  final String? imageUrl;
  final String? deepLink;

  PromoModel({
    required this.id,
    required this.title,
    required this.tag,
    required this.hexColors,
    required this.iconKey,
    this.imageUrl,
    this.deepLink,
  });

  List<Color> get colors {
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
    return PromoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
      hexColors: List<String>.from(json['colors'] ?? []),
      iconKey: json['icon_key']?.toString() ?? '',
      imageUrl: json['image_url'],
      deepLink: json['deep_link'],
    );
  }
}

