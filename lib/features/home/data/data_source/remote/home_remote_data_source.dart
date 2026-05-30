import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lounge_model.dart';
import '../../../../lounge_details/data/room_model.dart';
import '../../../../lounge_details/data/extra_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges();
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId);
  Future<List<ExtraModel>> getExtras();
  Future<List<String>> getBookedRoomIds(String loungeId, DateTime start, DateTime end);
  Future<List<Map<String, dynamic>>> getBookingsForRoom(String roomId, DateTime date);
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl(this._client);
  
  // ... (keeping existing methods)

  @override
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  }) async {
    final user = _client.auth.currentUser;
    
    await _client.from('bookings').insert({
      'room_id': int.tryParse(roomId) ?? roomId,
      'lounge_id': int.tryParse(loungeId) ?? loungeId,
      'user_id': user?.id, // حجز مرتبط بالمستخدم المسجل حالياً
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_price': totalPrice,
      'status': 'confirmed',
    });
  }

  @override
  Future<List<LoungeModel>> getLounges() async {
    final response = await _client
        .from('lounges')
        .select();

    print("RAW DATA: $response");

    return (response as List)
        .map((e) => LoungeModel.fromJson(e))
        .toList();
  }
  // Future<List<LoungeModel>> getLounges() async {
  //
  //   final response = await _client.from('lounges').select();
  //   print(response);
  //   return (response as List).map((e) => LoungeModel.fromJson(e)).toList();
  //
  // }

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId) async {
    // Convert loungeId to int if it's numeric, as Supabase often uses int for IDs
    final dynamic filterId = int.tryParse(loungeId) ?? loungeId;
    
    final response = await _client
        .from('rooms')
        .select()
        .eq('lounge_id', filterId);
    
    print("ROOMS FETCHED for lounge $filterId: ${response.length} items");

    return (response as List).map((e) => RoomModel.fromJson(e)).toList();
  }

  @override
  Future<List<ExtraModel>> getExtras() async {
    final response = await _client.from('extras').select();
    print("EXTRAS FETCHED: ${response.length} items");
    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }

  @override
  Future<List<String>> getBookedRoomIds(String loungeId, DateTime start, DateTime end) async {
    final dynamic filterId = int.tryParse(loungeId) ?? loungeId;

    final response = await _client
        .from('bookings')
        .select('room_id')
        .eq('lounge_id', filterId)
        .neq('status', 'cancelled')
        .lt('start_time', end.toIso8601String())
        .gt('end_time', start.toIso8601String());

    return (response as List).map((e) => e['room_id'].toString()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingsForRoom(String roomId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('bookings')
        .select('start_time, end_time')
        .eq('room_id', int.tryParse(roomId) ?? roomId)
        .neq('status', 'cancelled')
        .gte('start_time', startOfDay.toIso8601String())
        .lt('start_time', endOfDay.toIso8601String());

    return List<Map<String, dynamic>>.from(response);
  }
}
