import 'dart:async';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/active_session_model.dart';
import '../../models/order_item_model.dart';

abstract class ActiveSessionRemoteDataSource {
  Future<ActiveSessionModel?> getActiveSession({String? bookingId});
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Stream<ActiveSessionModel?> watchUserActiveSession();
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
  Future<ActiveSessionModel?> getActiveSession({String? bookingId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    const selectQuery = '*, lounges(name), rooms(name, name_en), booking_items(*)';
    final now = DateTime.now();

    // 1. If specific booking ID requested
    if (bookingId != null && bookingId.isNotEmpty) {
      final response = await _client
          .from('bookings')
          .select(selectQuery)
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      final model = ActiveSessionModel.fromJson(Map<String, dynamic>.from(response));
      if (model.status == 'completed' || model.status == 'cancelled' || model.status == 'expired') {
        return null;
      }
      // Ensure session start time has arrived
      if (now.isBefore(model.startTime)) {
        return null;
      }
      return model;
    }

    // 2. Prioritize active in_progress sessions FIRST (only if start time has arrived)
    final activeResponse = await _client
        .from('bookings')
        .select(selectQuery)
        .eq('user_id', userId)
        .eq('status', 'in_progress')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeResponse != null) {
      final activeModel = ActiveSessionModel.fromJson(Map<String, dynamic>.from(activeResponse));
      final hasStarted = !now.isBefore(activeModel.startTime);
      final isExpired = now.isAfter(activeModel.endTime.add(const Duration(minutes: 5)));
      if (hasStarted && !isExpired) {
        return activeModel;
      }
    }

    // 3. Fallback to upcoming / pending sessions ONLY IF start time has arrived!
    final upcomingResponse = await _client
        .from('bookings')
        .select(selectQuery)
        .eq('user_id', userId)
        .or('status.eq.upcoming,status.eq.pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (upcomingResponse != null) {
      final upcomingModel = ActiveSessionModel.fromJson(Map<String, dynamic>.from(upcomingResponse));
      final hasStarted = !now.isBefore(upcomingModel.startTime);
      final isExpired = now.isAfter(upcomingModel.endTime.add(const Duration(minutes: 5)));
      if (hasStarted && !isExpired) {
        return upcomingModel;
      }
    }

    return null;
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
  Stream<ActiveSessionModel?> watchUserActiveSession() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) {
          try {
            final now = DateTime.now();
            final active = list.firstWhere(
              (e) => e['status'] == 'in_progress',
              orElse: () => <String, dynamic>{},
            );
            if (active.isEmpty) return null;
            final model = ActiveSessionModel.fromJson(active);
            if (now.isBefore(model.startTime)) return null;
            if (now.isAfter(model.endTime.add(const Duration(minutes: 5)))) return null;
            return model;
          } catch (_) {
            return null;
          }
        });
  }

  @override
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    try {
      await _client.rpc('extend_active_session', params: {
        'p_booking_id': bookingId,
        'p_additional_minutes': additionalMinutes,
        'p_additional_cost': additionalCost,
      });
    } catch (_) {
      try {
        await _client.rpc('extend_active_session', params: {
          'booking_id': bookingId,
          'additional_minutes': additionalMinutes,
          'additional_cost': additionalCost,
        });
      } catch (_) {
        try {
          await _client.rpc('extend_booking_session', params: {
            'p_booking_id': bookingId,
            'p_additional_minutes': additionalMinutes,
            'p_added_cost': additionalCost,
          });
        } catch (_) {
          final booking = await _client
              .from('bookings')
              .select('end_time, extensions_price, total_price')
              .eq('id', bookingId)
              .single();
          final currentEnd = DateTime.parse(booking['end_time']);
          final newEnd = currentEnd.add(Duration(minutes: additionalMinutes));
          final currentExtPrice = (booking['extensions_price'] as num?)?.toDouble() ?? 0.0;
          final currentTotal = (booking['total_price'] as num?)?.toDouble() ?? 0.0;

          await _client.from('bookings').update({
            'end_time': newEnd.toIso8601String(),
            'extensions_price': currentExtPrice + additionalCost,
            'total_price': currentTotal + additionalCost,
          }).eq('id', bookingId);
        }
      }
    }
  }

  @override
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items) async {
    for (final item in items) {
      try {
        await _client.rpc('add_session_extra', params: {
          'p_booking_id': bookingId,
          'p_extra_id': item.id,
          'p_name': item.name,
          'p_quantity': item.quantity,
          'p_price': item.price,
          'p_notes': item.note,
        });
      } catch (_) {
        try {
          await _client.rpc('add_session_extra', params: {
            'booking_id': bookingId,
            'extra_id': item.id,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'note': item.note,
          });
        } catch (_) {
          await _client.from('booking_items').insert({
            'booking_id': bookingId,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'note': item.note,
          });
        }
      }
    }
  }

  @override
  Future<List<ExtraModel>> getLoungeMenu(String loungeId) async {
    try {
      final response = await _client
          .from('extras')
          .select()
          .eq('lounge_id', loungeId);

      return (response as List).map((e) => ExtraModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
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
