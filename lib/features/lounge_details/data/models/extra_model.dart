import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';

class ExtraModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final String category; // Drinks, Food, Snacks
  final String? icon;

  const ExtraModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.icon,
  });

  @override
  List<Object?> get props => [id, name, price, category, icon];

  factory ExtraModel.fromJson(Map<String, dynamic> json) {
    try {
      final nameStr = json['name']?.toString() ??
          json['name_ar']?.toString() ??
          json['name_en']?.toString() ??
          json['title']?.toString() ??
          json['item_name']?.toString() ??
          '';

      final iconStr = json['icon']?.toString() ??
          json['image']?.toString() ??
          json['image_url']?.toString();

      return ExtraModel(
        id: json['id']?.toString() ?? '',
        name: nameStr,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        category: json['category']?.toString() ?? json['category_name']?.toString() ?? '',
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
      'price': price,
      'category': category,
      'icon': icon,
    };
  }
}
