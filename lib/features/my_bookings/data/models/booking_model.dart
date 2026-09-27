import 'package:equatable/equatable.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/core/constants/app_config.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/models/payment_model.dart';

class BookingModel extends Equatable {
  final String id;
  final String? loungeId;
  final String? roomId;
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
    this.roomId,
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
        roomId,
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
    final bookingId = json['id']?.toString() ?? 'unknown';
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

    DateTime parsedDate = DateTime.now();
    bool dateParsedSuccessfully = false;

    if (json['date'] != null) {
      final dt = DateTime.tryParse(json['date'].toString());
      if (dt != null) {
        parsedDate = dt;
        dateParsedSuccessfully = true;
      }
    }
    if (!dateParsedSuccessfully && json['booking_period'] != null) {
      parsedDate = _parseTsRangeStart(json['booking_period'].toString());
      dateParsedSuccessfully = true;
    }
    if (!dateParsedSuccessfully && json['time_range'] != null) {
      parsedDate = _parseTsRangeStart(json['time_range'].toString());
      dateParsedSuccessfully = true;
    }

    if (!dateParsedSuccessfully) {
      AppLogger.warning("⚠️ [BookingModel.fromJson] Unresolvable date field for booking ID #$bookingId. Fallback: DateTime.now()");
    }

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

          final itemId = item['extra_id']?.toString() ??
              item['id']?.toString() ??
              item['addon_id']?.toString() ??
              item['product_id']?.toString() ??
              '';

          parsedCanteenItems.add({
            'id': itemId,
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

              final itemId = item['extra_id']?.toString() ??
                  item['id']?.toString() ??
                  extraData?['id']?.toString() ??
                  '';

              parsedCanteenItems.add({
                'id': itemId,
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

    final parsedTotalPrice = (json['total_price'] as num?)?.toDouble();
    if (parsedTotalPrice == null) {
      AppLogger.warning("⚠️ [BookingModel.fromJson] Missing or null total_price for booking ID #$bookingId. Fallback: 0.0");
    }

    return BookingModel(
      id: bookingId,
      loungeId: json['lounge_id']?.toString() ?? loungeData?['id']?.toString(),
      roomId: json['room_id']?.toString() ?? roomData?['id']?.toString(),
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
      totalPrice: parsedTotalPrice ?? 0.0,
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
      proofImageUrl: () {
        final paymentsData = json['payments'] is Map<String, dynamic>
            ? json['payments'] as Map<String, dynamic>
            : (json['payments'] is List && (json['payments'] as List).isNotEmpty && (json['payments'] as List).first is Map<String, dynamic>
                ? (json['payments'] as List).first as Map<String, dynamic>
                : null);

        final rawProof = json['proof_image_url']?.toString() ??
            json['receipt_url']?.toString() ??
            json['proof_url']?.toString() ??
            json['receipt_image_url']?.toString() ??
            json['payment_receipt_url']?.toString() ??
            json['payment_proof_url']?.toString() ??
            json['receipt_image']?.toString() ??
            json['proof_image']?.toString() ??
            json['receipt']?.toString() ??
            json['proof']?.toString() ??
            json['image_url']?.toString() ??
            paymentsData?['proof_image_url']?.toString() ??
            paymentsData?['receipt_url']?.toString() ??
            paymentsData?['proof_url']?.toString() ??
            paymentsData?['receipt_image_url']?.toString() ??
            paymentsData?['image_url']?.toString();

        if (rawProof != null && rawProof.trim().isNotEmpty && rawProof != 'null' && rawProof != 'undefined') {
          final clean = rawProof.trim();
          if (clean.startsWith('http://') || clean.startsWith('https://')) {
            return clean;
          }
          final cleanPath = clean.replaceAll(RegExp(r'^(receipts/|payment-proofs/)'), '');
          return '${AppConfig.supabaseUrl}/storage/v1/object/public/receipts/$cleanPath';
        }

        return null;
      }(),
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
