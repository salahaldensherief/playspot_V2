import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_model.dart';

abstract class MyBookingsRemoteDataSource {
  Future<List<BookingModel>> getMyBookings();
  Future<void> cancelBooking(String bookingId);
}

class MyBookingsRemoteDataSourceImpl implements MyBookingsRemoteDataSource {
  final SupabaseClient _client;

  MyBookingsRemoteDataSourceImpl(this._client);

  @override
  Future<List<BookingModel>> getMyBookings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    final response = await _client
        .from('bookings')
        .select('*, lounges(name, location, maps_link, lat, lng), rooms(name, name_en, controllers_count, screen_size)')
        .eq('user_id', userId)
        .order('date', ascending: false);

    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
  }
}
