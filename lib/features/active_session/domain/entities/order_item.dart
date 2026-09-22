import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final double? totalPriceOverride;
  final String? note;

  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.totalPriceOverride,
    this.note,
  });

  @override
  List<Object?> get props => [id, name, price, quantity, totalPriceOverride, note];

  double get total {
    final override = totalPriceOverride;
    if (override != null && override > 0) {
      return override;
    }
    return price * quantity;
  }
}
