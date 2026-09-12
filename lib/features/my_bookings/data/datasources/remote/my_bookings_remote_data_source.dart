import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/core/models/paginated_response.dart';
import '../../models/booking_model.dart';

abstract class MyBookingsRemoteDataSource {
  Future<List<BookingModel>> getMyBookings();
  Future<PaginatedResponse<BookingModel>> getLoungeBookingsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  });
  Future<void> cancelBooking(String bookingId);
}

class MyBookingsRemoteDataSourceImpl implements MyBookingsRemoteDataSource {
  final SupabaseClient _client;

  MyBookingsRemoteDataSourceImpl(this._client);

  @override
  Future<List<BookingModel>> getMyBookings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException("User not logged in");

    final response = await _client
        .from('bookings')
        .select('*, lounges(*), rooms(name, name_en, controllers_count, screen_size, space_types(label, name))')
        .eq('user_id', userId)
        .order('date', ascending: false);

    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  @override
  Future<PaginatedResponse<BookingModel>> getLoungeBookingsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.rpc('get_lounge_bookings_page', params: {
      'p_lounge_id': loungeId,
      'p_page': page,
      'p_page_size': pageSize,
    });

    return PaginatedResponse.fromRpc(
      response: response,
      fromJson: (json) => BookingModel.fromJson(json),
      requestedPage: page,
      requestedPageSize: pageSize,
    );
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
  }
}
