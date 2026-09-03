import 'package:equatable/equatable.dart';
import 'order_item_model.dart';

class CanteenOrderModel extends Equatable {
  final String? id;
  final String bookingId;
  final String loungeId;
  final String userId;
  final List<OrderItemModel> items;
  final double totalPrice;
  final String? note;
  final String? status;
  final DateTime? createdAt;

  const CanteenOrderModel({
    this.id,
    required this.bookingId,
    required this.loungeId,
    required this.userId,
    required this.items,
    required this.totalPrice,
    this.note,
    this.status,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        bookingId,
        loungeId,
        userId,
        items,
        totalPrice,
        note,
        status,
        createdAt,
      ];

  factory CanteenOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<OrderItemModel> itemsList = [];

    if (rawItems is List) {
      itemsList = rawItems.map((item) {
        if (item is Map<String, dynamic>) {
          return OrderItemModel.fromJson(item);
        } else if (item is Map) {
          return OrderItemModel.fromJson(Map<String, dynamic>.from(item));
        } else {
          return OrderItemModel(
            id: '',
            name: item.toString(),
            price: 0.0,
            quantity: 1,
          );
        }
      }).toList();
    }

    return CanteenOrderModel(
      id: json['id']?.toString(),
      bookingId: json['booking_id']?.toString() ?? '',
      loungeId: json['lounge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      items: itemsList,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      note: json['note']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'booking_id': bookingId,
        'lounge_id': loungeId,
        'user_id': userId,
        'items': items.map((e) => e.toJson()).toList(),
        'total_price': totalPrice,
        if (note != null) 'note': note,
        if (status != null) 'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
