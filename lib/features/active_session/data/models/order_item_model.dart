import 'package:equatable/equatable.dart';

class OrderItemModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final double? totalPriceOverride;
  final String? note;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.totalPriceOverride,
    this.note,
  });

  @override
  List<Object?> get props => [id, name, price, quantity, totalPriceOverride, note];

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final extraData = json['extras'] as Map<String, dynamic>? ??
        json['products'] as Map<String, dynamic>? ??
        json['item'] as Map<String, dynamic>?;

    final String rawName = json['name_ar']?.toString() ??
        json['name_en']?.toString() ??
        json['name']?.toString() ??
        json['product_name']?.toString() ??
        json['extra_name']?.toString() ??
        json['item_name']?.toString() ??
        json['title']?.toString() ??
        extraData?['name_ar']?.toString() ??
        extraData?['name_en']?.toString() ??
        extraData?['name']?.toString() ??
        json['description']?.toString() ??
        '';

    final String finalName = rawName.trim().isNotEmpty ? rawName.trim() : 'صنف';

    final int parsedQty = (json['quantity'] as num?)?.toInt() ?? 1;

    final double? rawTotal = (json['total_price'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble();

    double parsedPrice = (json['unit_price'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        (json['item_price'] as num?)?.toDouble() ??
        (extraData?['price'] as num?)?.toDouble() ??
        0.0;

    if (parsedPrice == 0.0 && rawTotal != null && rawTotal > 0) {
      parsedPrice = rawTotal / (parsedQty > 0 ? parsedQty : 1);
    }

    return OrderItemModel(
      id: json['id']?.toString() ?? json['extra_id']?.toString() ?? json['product_id']?.toString() ?? extraData?['id']?.toString() ?? '',
      name: finalName,
      price: parsedPrice,
      quantity: parsedQty,
      totalPriceOverride: rawTotal,
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

  double get total {
    if (totalPriceOverride != null && totalPriceOverride! > 0) {
      return totalPriceOverride!;
    }
    return price * quantity;
  }
}
