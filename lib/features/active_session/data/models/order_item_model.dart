import 'package:equatable/equatable.dart';

class OrderItemModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? note;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.note,
  });

  @override
  List<Object?> get props => [id, name, price, quantity, note];

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Check joined extras relation from canteen_order_items
    final extraData = json['extras'] as Map<String, dynamic>?;

    final String parsedName = extraData?['name_ar']?.toString() ??
        extraData?['name']?.toString() ??
        extraData?['name_en']?.toString() ??
        json['name']?.toString() ??
        json['item_name']?.toString() ??
        json['title']?.toString() ??
        '';

    final double parsedPrice = (json['unit_price'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        (extraData?['price'] as num?)?.toDouble() ??
        0.0;

    final int parsedQty = (json['quantity'] as num?)?.toInt() ?? 1;

    return OrderItemModel(
      id: json['id']?.toString() ?? extraData?['id']?.toString() ?? '',
      name: parsedName,
      price: parsedPrice,
      quantity: parsedQty,
      note: json['note']?.toString() ?? json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'note': note,
      };

  double get total => price * quantity;
}
