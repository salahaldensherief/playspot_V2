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
    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      note: json['note']?.toString(),
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
