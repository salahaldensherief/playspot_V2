import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double roomPrice,
    List<Map<String, dynamic>> extras = const [],
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient _client;

  BookingRemoteDataSourceImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final response = await _client.rpc(
      'get_room_bookings_for_date',
      params: {
        'p_lounge_id': loungeId,
        'p_date': dateStr,
      },
    );

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double roomPrice,
    List<Map<String, dynamic>> extras = const [],
  }) async {
    final user = _client.auth.currentUser;
    final duration = endTime.difference(startTime).inHours;
    
    final datePart = "${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}";
    final startPart = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
    final endPart = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";

    // استخدام RPC لضمان تنفيذ الحجز والإضافات كعملية واحدة (Atomic)
    // ولضمان التوافق مع منطق الداشبورد
    await _client.rpc('create_booking', params: {
      'p_room_id': int.tryParse(roomId) ?? roomId,
      'p_lounge_id': int.tryParse(loungeId) ?? loungeId,
      'p_user_id': user?.id,
      'p_date': datePart,
      'p_start_time': startPart,
      'p_end_time': endPart,
      'p_duration_hours': duration,
      'p_total_price': totalPrice,
      'p_room_price': roomPrice,
      'p_extras': extras, // سيتم إرسالها كـ JSONB وتفريغها في جدول الإضافات هناك
    });
  }
}
