import 'package:playspot/core/constants/booking_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_params.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params);
  Future<void> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  });
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  });
  Future<void> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  });
  Future<void> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient _client;

  BookingRemoteDataSourceImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final response = await _client
        .from('bookings')
        .select('room_id, start_time, end_time, date, status, start_at, end_at')
        .eq('lounge_id', loungeId)
        .eq('date', dateStr);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params) async {
    final user = _client.auth.currentUser;
    
    final datePart = "${params.startTime.year}-${params.startTime.month.toString().padLeft(2, '0')}-${params.startTime.day.toString().padLeft(2, '0')}";
    final startPart = "${params.startTime.hour.toString().padLeft(2, '0')}:${params.startTime.minute.toString().padLeft(2, '0')}:00";
    final endPart = "${params.endTime.hour.toString().padLeft(2, '0')}:${params.endTime.minute.toString().padLeft(2, '0')}:00";

    final response = await _client.from('bookings').insert({
      'room_id': params.roomId,
      'room_name': params.roomName,
      'lounge_id': params.loungeId,
      'user_id': user?.id,
      'user_name': params.userName,
      'user_phone': params.userPhone,
      'date': datePart,
      'start_time': startPart,
      'end_time': endPart,
      'total_price': params.totalPrice,
      'room_price': params.roomPrice,
      'status': BookingStatus.mapToDbStatus(params.status),
      'payment_status': params.paymentStatus,
      'booking_extras': params.addOns,
      'play_mode': params.playMode,
    }).select('id').single();

    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  }) async {
    try {
      await _client.rpc('extend_booking_session', params: {
        'p_booking_id': bookingId,
        'p_additional_minutes': additionalMinutes,
        'p_added_cost': additionalCost,
      });
    } catch (e) {
      try {
        final booking = await _client.from('bookings').select('end_time, extensions_price, total_price').eq('id', bookingId).single();
        final currentEnd = DateTime.parse(booking['end_time']);
        final newEnd = currentEnd.add(Duration(minutes: additionalMinutes));
        final currentExtPrice = (booking['extensions_price'] as num?)?.toDouble() ?? 0.0;
        final currentTotal = (booking['total_price'] as num?)?.toDouble() ?? 0.0;

        await _client.from('bookings').update({
          'end_time': newEnd.toIso8601String(),
          'extensions_price': currentExtPrice + additionalCost,
          'total_price': currentTotal + additionalCost,
        }).eq('id', bookingId);
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  @override
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    await _client.from('bookings').update({
      'extension_status': 'pending',
      'requested_extension_minutes': requestedMinutes,
    }).eq('id', bookingId);
  }

  @override
  Future<void> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  }) async {
    await _client.rpc('call_staff_request', params: {
      'p_lounge_id': loungeId,
      'p_booking_id': bookingId,
      'p_reason': reason,
      'p_note': note,
    });
  }

  @override
  Future<void> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  }) async {
    await _client.rpc('place_canteen_order', params: {
      'p_booking_id': bookingId,
      'p_lounge_id': loungeId,
      'p_user_id': userId,
      'p_items': items,
      'p_total_price': totalPrice,
      'p_note': note,
    });
  }
}
