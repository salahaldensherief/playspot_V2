import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import 'booking_model.dart';
import 'booking_dates_decoder.dart';
import 'booking_items_decoder.dart';
import 'booking_payment_decoder.dart';

class BookingJsonDecoder {
  static BookingModel decode(Map<String, dynamic> json) {
    final loungeData = json['lounges'] is Map
        ? Map<String, dynamic>.from(json['lounges'])
        : <String, dynamic>{};
    final roomData = json['rooms'] is Map
        ? Map<String, dynamic>.from(json['rooms'])
        : <String, dynamic>{};
    final point =
        GeoCoordinates.fromJson(loungeData) ?? GeoCoordinates.fromJson(json);
    final dates = BookingDatesDecoder(json);
    final payments = BookingPaymentDecoder(json);
    return BookingModel(
      id: json['id']?.toString() ?? 'unknown',
      loungeId: json['lounge_id']?.toString() ?? loungeData['id']?.toString(),
      roomId: json['room_id']?.toString() ?? roomData['id']?.toString(),
      loungeName: loungeData['name'] ?? '',
      loungeLocation: loungeData['location'] ?? '',
      roomName: roomData['name_en'] ?? roomData['name'] ?? '',
      spaceType: roomData['space_types']?['label'],
      spaceTypeName: roomData['space_types']?['name'],
      controllersCount: (roomData['controllers_count'] as num?)?.toInt() ?? 0,
      extraControllers: (json['extra_controllers'] as num?)?.toInt() ?? 0,
      screenSize: roomData['screen_size']?.toString() ?? '',
      date: dates.date,
      startTime: dates.startTime,
      endTime: json['end_time']?.toString() ?? '',
      status: BookingStatus.fromString(json['status']?.toString()),
      paymentStatus: json['payment_status'] ?? 'unpaid',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      playMode: json['play_mode'],
      mapsLink: loungeData['maps_link'],
      lat: point?.latitude,
      lng: point?.longitude,
      startDateTime: dates.startDateTime,
      canteenItems: BookingItemsDecoder.decode(json),
      paymentMethod: json['payment_method']?.toString(),
      isFirstBooking: json['is_first_booking'] as bool?,
      checkedInAt: dates.optional('checked_in_at'),
      cancellationReason: json['cancellation_reason']?.toString(),
      senderAccount:
          json['sender_account']?.toString() ??
          json['sender_wallet_phone']?.toString(),
      transactionReference:
          json['transaction_reference']?.toString() ??
          json['reference_number']?.toString(),
      proofImageUrl: payments.proofImageUrl,
      holdExpiresAt: dates.holdExpiresAt,
      rejectionReason:
          json['rejection_reason']?.toString() ??
          json['cancellation_reason']?.toString(),
      paidAt: payments.paidAt,
      payment: payments.payment,
    );
  }
}
