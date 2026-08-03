import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconKey;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  IconData get icon {
    switch (iconKey) {
      case 'sports_esports':
        return Icons.sports_esports;
      case 'computer':
        return Icons.computer;
      case 'view_in_ar':
        return Icons.view_in_ar;
      case 'sports_pool':
        return Icons.sports_baseball_rounded;
      case 'live_tv':
        return Icons.live_tv;
      case 'videogame_asset':
        return Icons.videogame_asset;
      default:
        return Icons.category;
    }
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? '',
    );
  }
}
