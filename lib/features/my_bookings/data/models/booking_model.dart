import 'package:equatable/equatable.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/models/payment_model.dart';

class BookingModel extends Equatable {
  final String id;
  final String? loungeId;
  final String loungeName;
  final String loungeLocation;
  final String roomName;
  final String? spaceType;
  final String? spaceTypeName;
  final int controllersCount;
  final String screenSize;
  final DateTime date;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final String paymentStatus; // unpaid, paid, refunded, partially_paid
  final double totalPrice;
  final String? playMode;
  final String? mapsLink;
  final double? lat;
  final double? lng;
  final DateTime startDateTime;
  final List<Map<String, dynamic>> canteenItems;
  final String? paymentMethod;
  final bool? isFirstBooking;
  final DateTime? checkedInAt;
  final String? cancellationReason;
  final String? senderAccount;
  final String? transactionReference;
  final String? proofImageUrl;
  final DateTime? holdExpiresAt;
  final String? rejectionReason;
  final DateTime? paidAt;
  final PaymentModel? payment;

  const BookingModel({
    required this.id,
    this.loungeId,
    required this.loungeName,
    required this.loungeLocation,
    required this.roomName,
    this.spaceType,
    this.spaceTypeName,
    required this.controllersCount,
    required this.screenSize,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.paymentStatus,
    required this.totalPrice,
    this.playMode,
    this.mapsLink,
    this.lat,
    this.lng,
    required this.startDateTime,
    this.canteenItems = const [],
    this.paymentMethod,
    this.isFirstBooking,
    this.checkedInAt,
    this.cancellationReason,
    this.senderAccount,
    this.transactionReference,
    this.proofImageUrl,
    this.holdExpiresAt,
    this.rejectionReason,
    this.paidAt,
    this.payment,
  });

  bool get isUpcoming => status == BookingStatus.upcoming || status == BookingStatus.pending;
  bool get hasCanteenOrders => canteenItems.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        loungeId,
        loungeName,
        loungeLocation,
        roomName,
        spaceType,
        spaceTypeName,
        controllersCount,
        screenSize,
        date,
        startTime,
        endTime,
        status,
        paymentStatus,
        totalPrice,
        playMode,
        mapsLink,
        lat,
        lng,
        startDateTime,
        canteenItems,
        paymentMethod,
        isFirstBooking,
        checkedInAt,
        cancellationReason,
        senderAccount,
        transactionReference,
        proofImageUrl,
        holdExpiresAt,
        rejectionReason,
        paidAt,
        payment,
      ];

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final loungeData = json['lounges'] as Map<String, dynamic>?;
    final roomData = json['rooms'] as Map<String, dynamic>?;

    double? parsedLat = (loungeData?['latitude'] as num?)?.toDouble() ??
        (loungeData?['lat'] as num?)?.toDouble() ??
        (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble();
    double? parsedLng = (loungeData?['longitude'] as num?)?.toDouble() ??
        (loungeData?['lng'] as num?)?.toDouble() ??
        (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble();

    if (parsedLat == null && loungeData?['location_point'] != null) {
      final loc = loungeData!['location_point'];
      if (loc is Map && loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        parsedLng = (loc['coordinates'][0] as num).toDouble();
        parsedLat = (loc['coordinates'][1] as num).toDouble();
      }
    }

    final parsedDate = json['date'] != null 
        ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now()) 
        : (json['booking_period'] != null 
            ? _parseTsRangeStart(json['booking_period'].toString()) 
            : (json['time_range'] != null 
                ? _parseTsRangeStart(json['time_range'].toString()) 
                : DateTime.now()));

    final rawStartTime = json['start_time']?.toString() ?? '';
    DateTime parsedStartDateTime = parsedDate;

    if (rawStartTime.contains('T')) {
      parsedStartDateTime = DateTime.tryParse(rawStartTime) ?? parsedDate;
    } else if (rawStartTime.isNotEmpty) {
      final parts = rawStartTime.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        parsedStartDateTime = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          hour,
          minute,
        );
      }
    }

    final List<Map<String, dynamic>> parsedCanteenItems = [];

    final bookingItems = json['items'] as List? ?? json['booking_items'] as List?;
    if (bookingItems != null && bookingItems.isNotEmpty) {
      for (var item in bookingItems) {
        if (item is Map) {
          final rawName = item['name_ar']?.toString() ??
              item['name_en']?.toString() ??
              item['name']?.toString() ??
              item['product_name']?.toString() ??
              item['extra_name']?.toString() ??
              item['item_name']?.toString() ??
              item['title']?.toString() ??
              'صنف';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final rawTotal = (item['total_price'] as num?)?.toDouble() ??
              (item['total'] as num?)?.toDouble();
          double unitPrice = (item['unit_price'] as num?)?.toDouble() ??
              (item['price'] as num?)?.toDouble() ??
              0.0;
          if (unitPrice == 0.0 && rawTotal != null && rawTotal > 0) {
            unitPrice = rawTotal / (qty > 0 ? qty : 1);
          }
          final totalPrice = rawTotal ?? (unitPrice * qty);

          parsedCanteenItems.add({
            'name': rawName.trim().isNotEmpty ? rawName.trim() : 'صنف',
            'quantity': qty,
            'unit_price': unitPrice,
            'total_price': totalPrice,
          });
        }
      }
    }

    final canteenOrders = json['canteen_orders'] as List?;
    if (canteenOrders != null && canteenOrders.isNotEmpty) {
      for (var cOrder in canteenOrders) {
        if (cOrder is! Map) continue;
        final cItems = cOrder['items'] as List? ?? cOrder['canteen_order_items'] as List?;
        if (cItems != null) {
          for (var item in cItems) {
            if (item is Map) {
              final extraData = item['extras'] as Map<String, dynamic>?;
              final rawName = item['name_ar']?.toString() ??
                  item['name_en']?.toString() ??
                  item['name']?.toString() ??
                  item['product_name']?.toString() ??
                  item['extra_name']?.toString() ??
                  extraData?['name_ar']?.toString() ??
                  extraData?['name_en']?.toString() ??
                  extraData?['name']?.toString() ??
                  item['item_name']?.toString() ??
                  'صنف';
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final rawTotal = (item['total_price'] as num?)?.toDouble() ??
                  (item['total'] as num?)?.toDouble();
              double price = (item['unit_price'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  (extraData?['price'] as num?)?.toDouble() ??
                  0.0;
              if (price == 0.0 && rawTotal != null && rawTotal > 0) {
                price = rawTotal / (qty > 0 ? qty : 1);
              }
              final total = rawTotal ?? (price * qty);

              parsedCanteenItems.add({
                'name': rawName.trim().isNotEmpty ? rawName.trim() : 'إضافة',
                'quantity': qty,
                'unit_price': price,
                'total_price': total,
              });
            }
          }
        }
      }
    }

    final checkedInStr = json['checked_in_at']?.toString();
    final parsedCheckedIn = checkedInStr != null ? DateTime.tryParse(checkedInStr) : null;

    final holdExpiresStr = (json['hold_expires_at'] ?? json['expires_at'])?.toString();
    final parsedHoldExpires = holdExpiresStr != null ? DateTime.tryParse(holdExpiresStr) : null;

    final parsedRejection = json['rejection_reason']?.toString() ?? json['cancellation_reason']?.toString();

    final rawPaidAt = json['paid_at'] ??
        (json['payments'] is Map ? json['payments']['paid_at'] : null) ??
        (json['payments'] is List && (json['payments'] as List).isNotEmpty ? json['payments'][0]['paid_at'] : null);
    DateTime? parsedPaidAt;
    if (rawPaidAt != null) {
      try {
        parsedPaidAt = DateTime.parse(rawPaidAt.toString());
      } catch (_) {
        parsedPaidAt = DateTime.tryParse(rawPaidAt.toString());
      }
    }

    PaymentModel? parsedPayment;
    if (json['payments'] is Map<String, dynamic>) {
      parsedPayment = PaymentModel.fromJson(json['payments'] as Map<String, dynamic>);
    } else if (json['payments'] is List && (json['payments'] as List).isNotEmpty && (json['payments'] as List).first is Map<String, dynamic>) {
      parsedPayment = PaymentModel.fromJson((json['payments'] as List).first as Map<String, dynamic>);
    }

    return BookingModel(
      id: json['id'].toString(),
      loungeId: json['lounge_id']?.toString() ?? loungeData?['id']?.toString(),
      loungeName: loungeData?['name'] ?? '',
      loungeLocation: loungeData?['location'] ?? '',
      roomName: roomData?['name_en'] ?? roomData?['name'] ?? '',
      spaceType: roomData?['space_types']?['label'],
      spaceTypeName: roomData?['space_types']?['name'],
      controllersCount: (roomData?['controllers_count'] as num?)?.toInt() ?? 0,
      screenSize: roomData?['screen_size']?.toString() ?? '',
      date: parsedDate,
      startTime: rawStartTime,
      endTime: json['end_time']?.toString() ?? '',
      status: BookingStatus.fromString(json['status']?.toString()),
      paymentStatus: json['payment_status'] ?? 'unpaid',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      playMode: json['play_mode'],
      mapsLink: loungeData?['maps_link'],
      lat: parsedLat,
      lng: parsedLng,
      startDateTime: parsedStartDateTime,
      canteenItems: parsedCanteenItems,
      paymentMethod: json['payment_method']?.toString(),
      isFirstBooking: json['is_first_booking'] as bool?,
      checkedInAt: parsedCheckedIn,
      cancellationReason: json['cancellation_reason']?.toString(),
      senderAccount: json['sender_account']?.toString() ?? json['sender_wallet_phone']?.toString(),
      transactionReference: json['transaction_reference']?.toString() ?? json['reference_number']?.toString(),
      proofImageUrl: json['proof_image_url']?.toString() ?? json['receipt_url']?.toString(),
      holdExpiresAt: parsedHoldExpires,
      rejectionReason: parsedRejection,
      paidAt: parsedPaidAt,
      payment: parsedPayment,
    );
  }

  static DateTime _parseTsRangeStart(String rangeStr) {
    try {
      final cleanStr = rangeStr.replaceAll(RegExp(r'["\[\])]'), '');
      final parts = cleanStr.split(',');
      if (parts.isNotEmpty) {
        return DateTime.parse(parts[0].trim());
      }
    } catch (_) {}
    return DateTime.now();
  }
}
