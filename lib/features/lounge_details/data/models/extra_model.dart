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
      return ExtraModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        category: json['category']?.toString() ?? '',
        icon: json['icon']?.toString(),
      );
    } catch (e) {
      print("Error parsing ExtraModel: $e");
      rethrow;
    }
  }
}
