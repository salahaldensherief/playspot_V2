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
    final ordersData = json['booking_items'] as List? ?? [];

    final loungeName = loungeData?['name']?.toString() ??
        json['lounge_name']?.toString() ??
        json['loungeName']?.toString() ??
        '';

    final roomName = roomData?['name_en'] ??
        roomData?['name'] ??
        json['room_name']?.toString() ??
        json['roomName']?.toString() ??
        '';

    // 1. Calculate Start Time (Convert UTC to Local)
    final startTime = _parseStartTime(json);

    // 2. Read Duration Minutes from Supabase
    final rawDuration = json['duration_minutes'] ??
        json['duration'] ??
        json['booking_duration'] ??
        json['play_duration'];

    int durationMins = 0;
    if (rawDuration is num) {
      durationMins = rawDuration.toInt();
    } else if (rawDuration is String) {
      durationMins = int.tryParse(rawDuration) ?? 0;
    }

    if (durationMins == 0 && json['duration_hours'] != null) {
      final hours = (json['duration_hours'] as num?)?.toDouble();
      if (hours != null) {
        durationMins = (hours * 60).round();
      }
    }

    // 3. Fallback calculation if duration_minutes is missing in DB:
    // Compute duration from total_price / room_price (or hourly rate)
    final totalPrice = (json['total_price'] as num?)?.toDouble() ??
        (json['base_price'] as num?)?.toDouble() ??
        0.0;
    final roomPrice = (json['room_price'] as num?)?.toDouble() ??
        (json['hourly_rate'] as num?)?.toDouble() ??
        (roomData?['hourly_rate_single'] as num?)?.toDouble() ??
        0.0;

    if (durationMins == 0 && totalPrice > 0 && roomPrice > 0) {
      durationMins = ((totalPrice / roomPrice) * 60).round();
    }

    // 4. Read Extended / Added Minutes
    final addedMins = (json['extended_minutes'] as num?)?.toInt() ??
        (json['added_minutes'] as num?)?.toInt() ??
        0;

    // 5. Calculate End Time matching Dashboard formula:
    // End Time = Start Time + Duration Minutes (+ Extra Extension Minutes)
    DateTime endTime;
    if (durationMins > 0) {
      endTime = startTime.add(Duration(minutes: durationMins + addedMins));
    } else {
      endTime = _parseEndTimeFallback(json, startTime);
      if (addedMins > 0) {
        endTime = endTime.add(Duration(minutes: addedMins));
      }
    }

    return ActiveSessionModel(
      bookingId: json['id']?.toString() ?? '',
      loungeId: json['lounge_id']?.toString() ?? '',
      loungeName: loungeName,
      roomName: roomName,
      deviceName: json['device_name']?.toString() ?? 'Station',
      startTime: startTime,
      endTime: endTime,
      basePrice: totalPrice,
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

  static DateTime _parseStartTime(Map<String, dynamic> json) {
    final rawStartTime = json['start_time'] ?? json['startTime'];
    final dateRaw = json['date'] ?? json['booking_date'];

    if (dateRaw != null && rawStartTime != null && rawStartTime.toString().isNotEmpty) {
      final dateStr = dateRaw.toString().split('T')[0].trim();
      String timeStr = rawStartTime.toString().trim();
      if (timeStr.contains(' ')) {
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts[1].toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        timeStr = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00";
      }
      try {
        final fullIso = "${dateStr}T$timeStr";
        final parsed = DateTime.parse(fullIso);
        return parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {}
    }

    final rawStartAt = json['start_at'] ?? json['startAt'];
    if (rawStartAt != null && rawStartAt.toString().isNotEmpty) {
      try {
        final parsed = DateTime.parse(rawStartAt.toString().trim());
        return parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {}
    }

    if (rawStartTime != null && rawStartTime.toString().contains('T')) {
      try {
        final parsed = DateTime.parse(rawStartTime.toString().trim());
        return parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {}
    }

    return DateTime.now();
  }

  static DateTime _parseEndTimeFallback(Map<String, dynamic> json, DateTime defaultStart) {
    final rawEndTime = json['end_time'] ?? json['endTime'];
    final dateRaw = json['date'] ?? json['booking_date'];

    if (dateRaw != null && rawEndTime != null && rawEndTime.toString().isNotEmpty) {
      final dateStr = dateRaw.toString().split('T')[0].trim();
      String timeStr = rawEndTime.toString().trim();
      if (timeStr.contains(' ')) {
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts[1].toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        timeStr = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00";
      }
      try {
        final fullIso = "${dateStr}T$timeStr";
        final parsed = DateTime.parse(fullIso);
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        if (local.isAfter(defaultStart)) return local;
      } catch (_) {}
    }

    final rawEndAt = json['end_at'] ?? json['endAt'];
    if (rawEndAt != null && rawEndAt.toString().isNotEmpty) {
      try {
        final parsed = DateTime.parse(rawEndAt.toString().trim());
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        if (local.isAfter(defaultStart)) return local;
      } catch (_) {}
    }

    if (rawEndTime != null && rawEndTime.toString().contains('T')) {
      try {
        final parsed = DateTime.parse(rawEndTime.toString().trim());
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        if (local.isAfter(defaultStart)) return local;
      } catch (_) {}
    }

    return defaultStart.add(const Duration(minutes: 30));
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
