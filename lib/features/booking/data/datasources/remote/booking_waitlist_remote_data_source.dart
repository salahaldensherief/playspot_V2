import 'package:supabase_flutter/supabase_flutter.dart';

class BookingWaitlistRemoteDataSource {
  final SupabaseClient client;

  const BookingWaitlistRemoteDataSource(this.client);

  Future<String?> activeRequest({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final row = await client
        .from('booking_waitlist')
        .select('id')
        .eq('room_id', roomId)
        .eq('start_at', startAt.toIso8601String())
        .eq('end_at', endAt.toIso8601String())
        .eq('status', 'waiting')
        .maybeSingle();
    return row?['id']?.toString();
  }

  Future<Map<String, dynamic>> join({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final result = await client.rpc('join_booking_waitlist', params: {
      'p_room_id': roomId,
      'p_start_at': startAt.toIso8601String(),
      'p_end_at': endAt.toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<bool> cancel(String requestId) async {
    final result = await client.rpc(
      'cancel_booking_waitlist',
      params: {'p_waitlist_id': requestId},
    );
    return result == true;
  }
}
