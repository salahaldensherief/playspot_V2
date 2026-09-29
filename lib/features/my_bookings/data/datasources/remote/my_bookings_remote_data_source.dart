import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/core/models/paginated_response.dart';
import '../../models/booking_model.dart';
import '../../models/booking_timeline_item_model.dart';

abstract class MyBookingsRemoteDataSource {
  Future<List<BookingModel>> getMyBookings();
  Future<PaginatedResponse<BookingModel>> getLoungeBookingsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  });
  Future<void> cancelBooking(String bookingId);
  Future<List<BookingTimelineItemModel>> getBookingTimeline(String bookingId);
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
        .select('*, lounges(*), rooms(name, name_en, controllers_count, screen_size, space_types(label, name)), canteen_orders(*, canteen_order_items(*, extras(id, name, name_ar, name_en, price)))')
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException("User not logged in");

    await _client.rpc(
      'cancel_my_booking',
      params: {
        'p_booking_id': bookingId,
        'p_reason': 'Cancelled by user',
      },
    );
  }

  @override
  Future<List<BookingTimelineItemModel>> getBookingTimeline(String bookingId) async {
    final response = await _client.rpc(
      'get_booking_timeline_for_customer',
      params: {'p_booking_id': bookingId},
    );

    final rawList = response as List? ?? [];
    final seenIds = <String>{};
    final items = <BookingTimelineItemModel>[];

    for (final raw in rawList) {
      if (raw is Map<String, dynamic>) {
        final model = BookingTimelineItemModel.fromJson(raw);
        if (seenIds.add(model.id)) {
          items.add(model);
        }
      }
    }

    return items;
  }
}
