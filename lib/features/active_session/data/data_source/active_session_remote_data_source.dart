import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/active_session_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';

abstract class ActiveSessionRemoteDataSource {
  Future<ActiveSessionModel?> getActiveSession();
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Future<void> extendTime(String bookingId, DateTime newEndTime, double additionalCost);
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items);
  Future<List<ExtraModel>> getLoungeMenu(String loungeId);
}

class ActiveSessionRemoteDataSourceImpl implements ActiveSessionRemoteDataSource {
  final SupabaseClient _client;

  ActiveSessionRemoteDataSourceImpl(this._client);

  @override
  Future<ActiveSessionModel?> getActiveSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('bookings')
        .select('*, lounges(name), rooms(name, name_en), booking_orders(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    if (response == null) return null;
    return ActiveSessionModel.fromJson(response);
  }

  @override
  Stream<ActiveSessionModel> streamActiveSession(String bookingId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((data) {
          if (data.isEmpty) throw Exception("Booking not found");
          // Note: stream doesn't support complex joins easily in the same way select does for nested objects if not configured
          // But we can do a fresh fetch or assume the UI will use this to trigger a refresh.
          // For now, let's assume we can map it if we get the full object or we might need a workaround.
          return ActiveSessionModel.fromJson(data.first);
        });
  }

  @override
  Future<void> extendTime(String bookingId, DateTime newEndTime, double additionalCost) async {
    // In a real app, you might have a RPC or multiple updates
    await _client.from('bookings').update({
      'end_time': newEndTime.toIso8601String(),
      'extensions_price': additionalCost, // Simplified: usually you add to existing
    }).eq('id', bookingId);
  }

  @override
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items) async {
    final orders = items.map((item) => {
      'booking_id': bookingId,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'note': item.note,
    }).toList();

    await _client.from('booking_orders').insert(orders);
  }

  @override
  Future<List<ExtraModel>> getLoungeMenu(String loungeId) async {
    final response = await _client
        .from('lounge_extras')
        .select('*')
        .eq('lounge_id', loungeId);

    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }
}
