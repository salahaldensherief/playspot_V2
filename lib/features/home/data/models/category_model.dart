import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class CategoryModel extends Equatable {
  final String id;
  final String nameAr;
  final String nameEn;
  final String iconKey;

  const CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.iconKey,
  });

  @override
  List<Object?> get props => [id, nameAr, nameEn, iconKey];

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
        return Icons.sports_golf;
      case 'sports_tennis':
        return Icons.sports_tennis;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'sports_motorsports':
        return Icons.sports_motorsports;
      case 'casino':
        return Icons.casino;
      case 'adjust':
        return Icons.adjust;
      case 'mic':
        return Icons.mic;
      case 'desktop_windows':
        return Icons.desktop_windows;
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
      nameAr: json['name_ar']?.toString() ?? json['name']?.toString() ?? json['name_en']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? json['name']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'icon_key': iconKey,
    };
  }
}
