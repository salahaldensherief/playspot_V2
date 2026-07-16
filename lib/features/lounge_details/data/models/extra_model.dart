class ExtraModel {
  final String id;
  final String name;
  final double price;
  final String category; // Drinks, Food, Snacks
  final String? icon;

  ExtraModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.icon,
  });

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
