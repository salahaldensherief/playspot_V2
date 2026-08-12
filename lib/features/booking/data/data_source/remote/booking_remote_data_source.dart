import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<void> createBooking({
    required String roomId,
    required String roomName,
    required String loungeId,
    required String userName,
    required String userPhone,
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
    required String roomName,
    required String loungeId,
    required String userName,
    required String userPhone,
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

    // إدخال مباشر في جدول bookings مع كافة التفاصيل لضمان ظهورها في الداشبورد
    await _client.from('bookings').insert({
      'room_id': roomId,
      'room_name': roomName,
      'lounge_id': loungeId,
      'user_id': user?.id,
      'user_name': userName,
      'user_phone': userPhone,
      'date': datePart,
      'start_time': startPart,
      'end_time': endPart,
      'duration_hours': duration,
      'total_price': totalPrice,
      'room_price': roomPrice,
      'status': 'pending', // حالة معلقة بانتظار موافقة صاحب الصالة
      'booking_extras': extras, // تفاصيل الأكل والمشروبات
    });
  }
}
