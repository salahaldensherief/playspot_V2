import 'package:equatable/equatable.dart';
import 'order_item.dart';

class ActiveSession extends Equatable {
  final String bookingId;
  final String loungeId;
  final String loungeName;
  final String roomName;
  final String deviceName;
  final DateTime startTime;
  final DateTime endTime;
  final double basePrice;
  final double extensionsPrice;
  final List<OrderItem> orders;
  final String status;
  final String? extensionStatus;
  final int? requestedExtensionMinutes;

  const ActiveSession({
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

  ActiveSession copyWith({
    String? bookingId,
    String? loungeId,
    String? loungeName,
    String? roomName,
    String? deviceName,
    DateTime? startTime,
    DateTime? endTime,
    double? basePrice,
    double? extensionsPrice,
    List<OrderItem>? orders,
    String? status,
    String? extensionStatus,
    int? requestedExtensionMinutes,
  }) {
    return ActiveSession(
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

  double get ordersTotal => orders.fold(0.0, (sum, item) => sum + item.total);
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

  /// Calculates extension cost based on basePrice / duration in hours * additionalMinutes
  double calculateExtensionCost(int additionalMinutes) {
    if (additionalMinutes <= 0) return 0.0;
    final totalBookedMinutes = endTime.difference(startTime).inMinutes;
    double hourlyRate = 50.0;
    if (totalBookedMinutes > 0 && basePrice > 0) {
      hourlyRate = basePrice / (totalBookedMinutes / 60.0);
    }
    final cost = (hourlyRate * (additionalMinutes / 60.0)).roundToDouble();
    return cost > 0 ? cost : (additionalMinutes * 0.83).roundToDouble();
  }

  int get totalPlayDurationMinutes {
    final diff = endTime.difference(startTime).inMinutes;
    return diff > 0 ? diff : 0;
  }

  String get formattedPlayDuration {
    final totalMins = totalPlayDurationMinutes;
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    if (hours > 0 && mins > 0) {
      return '$hours h $mins m';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$mins m';
    }
  }
}
