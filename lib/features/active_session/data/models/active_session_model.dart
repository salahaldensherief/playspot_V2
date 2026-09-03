import 'package:equatable/equatable.dart';
import 'order_item_model.dart';

class ActiveSessionModel extends Equatable {
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

  const ActiveSessionModel({
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

  @override
  List<Object?> get props => [
        bookingId,
        loungeId,
        loungeName,
        roomName,
        deviceName,
        startTime,
        endTime,
        basePrice,
        extensionsPrice,
        orders,
        status,
      ];

  ActiveSessionModel copyWith({
    String? bookingId,
    String? loungeId,
    String? loungeName,
    String? roomName,
    String? deviceName,
    DateTime? startTime,
    DateTime? endTime,
    double? basePrice,
    double? extensionsPrice,
    List<OrderItemModel>? orders,
    String? status,
  }) {
    return ActiveSessionModel(
      bookingId: bookingId ?? this.bookingId,
      loungeId: loungeId ?? this.loungeId,
      loungeName: loungeName ?? this.loungeName,
      roomName: roomName ?? this.roomName,
      deviceName: deviceName ?? this.deviceName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      basePrice: basePrice ?? this.basePrice,
      extensionsPrice: extensionsPrice ?? this.extensionsPrice,
      orders: orders ?? this.orders,
      status: status ?? this.status,
    );
  }

  factory ActiveSessionModel.fromJson(Map<String, dynamic> json) {
    final loungeData = json['lounges'] as Map<String, dynamic>?;
    final roomData = json['rooms'] as Map<String, dynamic>?;
    final ordersData = (json['booking_items'] ?? json['booking_orders']) as List? ?? [];

    final loungeName = loungeData?['name']?.toString() ??
        json['lounge_name']?.toString() ??
        json['loungeName']?.toString() ??
        '';

    final roomName = roomData?['name_en'] ??
        roomData?['name'] ??
        json['room_name']?.toString() ??
        json['roomName']?.toString() ??
        '';

    final dateRaw = json['date'] ?? json['booking_date'];
    final startTime = _parseDateTime(dateRaw, json['start_time']);
    final endTime = _parseDateTime(dateRaw, json['end_time']);

    return ActiveSessionModel(
      bookingId: json['id']?.toString() ?? '',
      loungeId: json['lounge_id']?.toString() ?? '',
      loungeName: loungeName,
      roomName: roomName,
      deviceName: json['device_name']?.toString() ?? 'Station',
      startTime: startTime,
      endTime: endTime,
      basePrice: (json['total_price'] as num?)?.toDouble() ??
          (json['base_price'] as num?)?.toDouble() ??
          0.0,
      extensionsPrice: (json['extensions_price'] as num?)?.toDouble() ?? 0.0,
      orders: ordersData
          .map((e) {
            try {
              return OrderItemModel.fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<OrderItemModel>()
          .toList(),
      status: json['status']?.toString() ?? 'in_progress',
    );
  }

  static DateTime _parseDateTime(dynamic dateRaw, dynamic timeRaw) {
    if (timeRaw == null) return DateTime.now();
    final timeStr = timeRaw.toString().trim();

    if (timeStr.contains('T')) {
      try {
        return DateTime.parse(timeStr);
      } catch (_) {}
    }

    final dateStr = dateRaw?.toString().trim();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final cleanDate = dateStr.split('T')[0];
        final fullIso = "${cleanDate}T$timeStr";
        return DateTime.parse(fullIso);
      } catch (_) {}
    }

    try {
      final parts = timeStr.split(':');
      final now = DateTime.now();
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final second = parts.length > 2 ? int.tryParse(parts[2].split('.')[0]) ?? 0 : 0;
        return DateTime(now.year, now.month, now.day, hour, minute, second);
      }
    } catch (_) {}

    return DateTime.now();
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
