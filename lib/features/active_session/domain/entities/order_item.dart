import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final double price;
  final int quantity;
  final double? totalPriceOverride;
  final String? note;
  final bool isCombo;
  final String? status;
  final String? upsellRuleId;

  const OrderItem({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.price,
    required this.quantity,
    this.totalPriceOverride,
    this.note,
    this.isCombo = false,
    this.status,
    this.upsellRuleId,
  });

  @override
  List<Object?> get props => [id, name, nameAr, nameEn, price, quantity, totalPriceOverride, note, isCombo, status, upsellRuleId];

  double get total {
    final override = totalPriceOverride;
    if (override != null && override > 0) {
      return override;
    }
    return price * quantity;
  }
}
