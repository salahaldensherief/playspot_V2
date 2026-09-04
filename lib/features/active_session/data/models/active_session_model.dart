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
  final String? extensionStatus;
  final int? requestedExtensionMinutes;

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
    this.extensionStatus,
    this.requestedExtensionMinutes,
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
        extensionStatus,
        requestedExtensionMinutes,
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
    String? extensionStatus,
    int? requestedExtensionMinutes,
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
      extensionStatus: extensionStatus ?? this.extensionStatus,
      requestedExtensionMinutes: requestedExtensionMinutes ?? this.requestedExtensionMinutes,
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
    DateTime endTime = _parseDateTime(dateRaw, json['end_time']);

    // Check for explicit duration in JSON
    final rawDuration = json['duration_minutes'] ??
        json['duration'] ??
        json['booking_duration'] ??
        json['play_duration'];

    int? durationMins;
    if (rawDuration != null) {
      if (rawDuration is num) {
        durationMins = rawDuration.toInt();
      } else if (rawDuration is String) {
        durationMins = int.tryParse(rawDuration);
      }
    }

    if (durationMins == null && json['duration_hours'] != null) {
      final hours = (json['duration_hours'] as num?)?.toDouble();
      if (hours != null) {
        durationMins = (hours * 60).round();
      }
    }

    if (durationMins != null && durationMins > 0) {
      final calculatedEnd = startTime.add(Duration(minutes: durationMins));
      if (calculatedEnd.isAfter(endTime)) {
        endTime = calculatedEnd;
      }
    }

    // Check for extra added/extended minutes
    final addedMins = (json['extended_minutes'] as num?)?.toInt() ??
        (json['added_minutes'] as num?)?.toInt() ??
        0;

    if (addedMins > 0) {
      endTime = endTime.add(Duration(minutes: addedMins));
    }

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
      extensionStatus: json['extension_status']?.toString(),
      requestedExtensionMinutes: (json['requested_extension_minutes'] as num?)?.toInt(),
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
        final parsed = DateTime.parse(timeStr);
        return parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {}
    }

    final dateStr = dateRaw?.toString().trim();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final cleanDate = dateStr.split('T')[0];
        String formattedTime = timeStr;
        if (timeStr.contains(' ')) {
          final parts = timeStr.split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final isPm = parts[1].toUpperCase() == 'PM';
          if (isPm && hour < 12) hour += 12;
          if (!isPm && hour == 12) hour = 0;
          formattedTime = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00";
        }
        final fullIso = "${cleanDate}T$formattedTime";
        final parsed = DateTime.parse(fullIso);
        return parsed.isUtc ? parsed.toLocal() : parsed;
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

  bool get hasStarted => !DateTime.now().isBefore(startTime);
  bool get isUpcoming => DateTime.now().isBefore(startTime);
  Duration get timeUntilStart => startTime.difference(DateTime.now());

  bool get isExtensionPending => extensionStatus == 'pending';
  bool get isExtensionRejected => extensionStatus == 'rejected';

  bool get isExpiringSoon {
    final remaining = endTime.difference(DateTime.now());
    return remaining.inMinutes > 0 && remaining.inMinutes <= 15;
  }

  bool get isOvertime {
    return DateTime.now().isAfter(endTime);
  }
}
