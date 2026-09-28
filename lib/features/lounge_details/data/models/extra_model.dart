import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';

class ExtraModel extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final String nameEn;
  final double price;
  final String category; // drinks, food, snacks, desserts, other
  final String? icon;

  const ExtraModel({
    required this.id,
    required this.name,
    String? nameAr,
    String? nameEn,
    required this.price,
    required this.category,
    this.icon,
  })  : nameAr = nameAr ?? name,
        nameEn = nameEn ?? name;

  @override
  List<Object?> get props => [id, name, nameAr, nameEn, price, category, icon];

  factory ExtraModel.fromJson(Map<String, dynamic> json) {
    try {
      final nameArStr = json['name_ar']?.toString() ?? json['name']?.toString() ?? json['title']?.toString() ?? json['item_name']?.toString() ?? '';
      final nameEnStr = json['name_en']?.toString() ?? json['name']?.toString() ?? json['title']?.toString() ?? json['item_name']?.toString() ?? '';
      final nameStr = json['name']?.toString() ?? (nameArStr.isNotEmpty ? nameArStr : nameEnStr);

      final iconStr = json['icon']?.toString() ??
          json['image']?.toString() ??
          json['image_url']?.toString();

      final rawCategory = json['category']?.toString() ??
          json['category_name']?.toString() ??
          json['category_slug']?.toString() ??
          'other';

      return ExtraModel(
        id: json['id']?.toString() ?? '',
        name: nameStr,
        nameAr: nameArStr.isNotEmpty ? nameArStr : nameStr,
        nameEn: nameEnStr.isNotEmpty ? nameEnStr : nameStr,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        category: rawCategory.trim().toLowerCase(),
        icon: iconStr,
      );
    } catch (e) {
      dev.log("Error parsing ExtraModel: $e");
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'name_en': nameEn,
      'price': price,
      'category': category.trim().toLowerCase(),
      'icon': icon,
    };
  }
}
