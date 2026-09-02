import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/active_session_model.dart';
import '../../models/order_item_model.dart';

abstract class ActiveSessionRemoteDataSource {
  Future<ActiveSessionModel?> getActiveSession();
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost);
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items);
  Future<List<ExtraModel>> getLoungeMenu(String loungeId);
  Future<void> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  });
  Future<void> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  });
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
        .select('*, lounges(name), rooms(name, name_en), booking_items(*)') // تم التعديل هنا
        .eq('user_id', userId)
        .eq('status', BookingStatus.inProgress)
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
      return ActiveSessionModel.fromJson(data.first);
    });
  }

  @override
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    await _client.rpc('extend_booking_session', params: {
      'p_booking_id': bookingId,
      'p_additional_minutes': additionalMinutes,
      'p_added_cost': additionalCost,
    });
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

    await _client.from('booking_items').insert(orders); // تم التعديل هنا
  }

  @override
  Future<List<ExtraModel>> getLoungeMenu(String loungeId) async {
    final response = await _client
        .from('lounge_extras')
        .select('*')
        .eq('lounge_id', loungeId);

    return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
  }

  @override
  Future<void> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.rpc('request_staff_assistance', params: {
      'p_booking_id': bookingId,
      'p_user_id': userId,
      'p_call_type': callType,
      'p_notes': notes,
    });
  }

  @override
  Future<void> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.rpc('submit_lounge_review', params: {
      'p_lounge_id': loungeId,
      'p_booking_id': bookingId,
      'p_user_id': userId,
      'p_rating': rating,
      'p_comment': comment,
    });
  }
}