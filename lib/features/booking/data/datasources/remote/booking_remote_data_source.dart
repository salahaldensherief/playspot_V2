import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_params.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient _client;

  BookingRemoteDataSourceImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    // Architect Note: Extreme simplification to bypass Postgres stack depth limit.
    // We only fetch the absolute minimum fields required for slot availability logic.
    final response = await _client
        .from('bookings')
        .select('room_id, start_time, end_time, date')
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

    // Architect Note: We explicitly use a lowercase literal string for status 
    // and only select 'id' to avoid triggering ambiguous Postgres RLS operators
    // or deep relational joins that cause stack depth issues.
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
      'status': params.status,
      'payment_status': params.paymentStatus,
      'booking_extras': params.addOns,
      'play_mode': params.playMode,
    }).select('id').single();

    return Map<String, dynamic>.from(response);
  }
}
