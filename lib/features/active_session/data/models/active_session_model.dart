import 'package:playspot/features/lounge_details/data/models/extra_model.dart';

class OrderItemModel {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? note;

  OrderItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.note,
  });

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

class ActiveSessionModel {
  final String bookingId;
  final String loungeId;
  final String loungeName;
  final String roomName;
  final String deviceName;
  final DateTime startTime;
  final DateTime endTime;
  final double basePrice;
  final double extensionsPrice;
  final List<OrderItemModel> orders;
  final String status;

  ActiveSessionModel({
    required this.bookingId,
    required this.loungeId,
    required this.loungeName,
    required this.roomName,
    required this.deviceName,
    required this.startTime,
    required this.endTime,
    required this.basePrice,
    this.extensionsPrice = 0.0,
    this.orders = const [],
    required this.status,
  });

  factory ActiveSessionModel.fromJson(Map<String, dynamic> json) {
    final loungeData = json['lounges'] as Map<String, dynamic>?;
    final roomData = json['rooms'] as Map<String, dynamic>?;
    final ordersData = json['booking_orders'] as List? ?? [];

    return ActiveSessionModel(
      bookingId: json['id']?.toString() ?? '',
      loungeId: json['lounge_id']?.toString() ?? '',
      loungeName: loungeData?['name'] ?? '',
      roomName: roomData?['name_en'] ?? roomData?['name'] ?? '',
      deviceName: json['device_name'] ?? 'Station', 
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      extensionsPrice: (json['extensions_price'] as num?)?.toDouble() ?? 0.0,
      orders: ordersData.map((e) => OrderItemModel.fromJson(e)).toList(),
      status: json['status'] ?? 'active',
    );
  }

  double get ordersTotal => orders.fold(0, (sum, item) => sum + item.total);
  double get grandTotal => basePrice + extensionsPrice + ordersTotal;
  
  bool get isExpiringSoon {
    final remaining = endTime.difference(DateTime.now());
    return remaining.inMinutes > 0 && remaining.inMinutes <= 15;
  }

  bool get isOvertime {
    return DateTime.now().isAfter(endTime);
  }
}
