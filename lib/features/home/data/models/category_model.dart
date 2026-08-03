import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String nameAr;
  final String nameEn;
  final String iconKey;

  CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.iconKey,
  });

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;

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
      nameAr: json['name_ar']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? '',
    );
  }
}
