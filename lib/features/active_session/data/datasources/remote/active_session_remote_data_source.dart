import 'dart:async';
import 'dart:developer' as dev;
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/active_session_model.dart';
import '../../models/order_item_model.dart';

abstract class ActiveSessionRemoteDataSource {
  Future<ActiveSessionModel?> getActiveSession({String? bookingId});
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Stream<ActiveSessionModel?> watchUserActiveSession();
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost);
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  });
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
    dev.log("[LIVESESSION_DS] GET_ACTIVE_SESSION: bookingId=$bookingId");
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      dev.log("[LIVESESSION_DS] Unauthenticated user");
      return null;
    }

    const selectQuery = '*, lounges(name), rooms(name, name_en), booking_items(*)';
    final now = DateTime.now();

    // 1. If specific booking ID requested
    if (bookingId != null && bookingId.isNotEmpty) {
      dev.log("[LIVESESSION_DS] Fetching specific booking: $bookingId");
      final response = await _client
          .from('bookings')
          .select(selectQuery)
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      final model = ActiveSessionModel.fromJson(Map<String, dynamic>.from(response));
      if (model.status == 'completed' || model.status == 'cancelled' || model.status == 'expired') {
        dev.log("[LIVESESSION_DS] Booking is finished: status=${model.status}");
        return null;
      }
      if (now.isBefore(model.startTime)) {
        dev.log("[LIVESESSION_DS] Booking start time has not arrived yet: ${model.startTime}");
        return null;
      }
      dev.log("[LIVESESSION_DS] GET_ACTIVE_SESSION SUCCESS: bookingId=${model.bookingId}");
      return model;
    }

    // 2. Prioritize active in_progress sessions FIRST
    dev.log("[LIVESESSION_DS] Fetching active in_progress session...");
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
        dev.log("[LIVESESSION_DS] Found active in_progress session: ${activeModel.bookingId}");
        return activeModel;
      }
    }

    // 3. Fallback to upcoming / pending sessions ONLY IF start time has arrived!
    dev.log("[LIVESESSION_DS] Checking upcoming/pending fallback sessions...");
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
        dev.log("[LIVESESSION_DS] Found valid upcoming/pending session that has started: ${upcomingModel.bookingId}");
        return upcomingModel;
      }
    }

    dev.log("[LIVESESSION_DS] No active session found");
    return null;
  }

  @override
  Stream<ActiveSessionModel> streamActiveSession(String bookingId) async* {
    dev.log("[LIVESESSION_DS] STREAM_ACTIVE_SESSION: bookingId=$bookingId");
    int retryCount = 0;
    while (true) {
      try {
        final stream = _client
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('id', bookingId);

        await for (final data in stream) {
          retryCount = 0; // Reset error count on successful event
          dev.log("[LIVESESSION_DS] REALTIME_EVENT received for booking $bookingId, rows: ${data.length}");
          if (data.isNotEmpty) {
            yield ActiveSessionModel.fromJson(data.first);
          }
        }
        dev.log("[LIVESESSION_DS] Realtime stream for booking $bookingId completed normally.");
        break;
      } catch (e, st) {
        retryCount++;
        dev.log(
          "[LIVESESSION_DS] REALTIME_STREAM_ERROR (Attempt $retryCount, code 1002 / channelError) for booking $bookingId: $e",
          error: e,
          stackTrace: st,
        );

        final backoffSeconds = (1 << (retryCount > 4 ? 4 : retryCount)).clamp(1, 10);
        dev.log("[LIVESESSION_DS] Unsubscribed failed channel. Re-subscribing in ${backoffSeconds}s...");
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  @override
  Stream<ActiveSessionModel?> watchUserActiveSession() async* {
    dev.log("[LIVESESSION_DS] WATCH_USER_ACTIVE_SESSION");
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      yield null;
      return;
    }

    int retryCount = 0;
    while (true) {
      try {
        final stream = _client
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId);

        await for (final list in stream) {
          retryCount = 0;
          try {
            final now = DateTime.now();
            final active = list.firstWhere(
              (e) => e['status'] == 'in_progress',
              orElse: () => <String, dynamic>{},
            );
            if (active.isEmpty) {
              yield null;
            } else {
              final model = ActiveSessionModel.fromJson(active);
              if (now.isBefore(model.startTime) || now.isAfter(model.endTime.add(const Duration(minutes: 5)))) {
                yield null;
              } else {
                dev.log("[LIVESESSION_DS] User active session updated via watch stream: ${model.bookingId}");
                yield model;
              }
            }
          } catch (e) {
            dev.log("[LIVESESSION_DS] Error parsing watch user session item: $e");
            yield null;
          }
        }
        break;
      } catch (e, st) {
        retryCount++;
        dev.log(
          "[LIVESESSION_DS] WATCH_USER_ACTIVE_SESSION STREAM_ERROR (Attempt $retryCount, code 1002 / channelError): $e",
          error: e,
          stackTrace: st,
        );

        final backoffSeconds = (1 << (retryCount > 4 ? 4 : retryCount)).clamp(1, 10);
        dev.log("[LIVESESSION_DS] Unsubscribed failed watch channel. Re-subscribing in ${backoffSeconds}s...");
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  @override
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    dev.log("[LIVESESSION_DS] EXTEND_TIME: bookingId=$bookingId, minutes=$additionalMinutes, cost=$additionalCost");
    try {
      await _client.rpc('extend_active_session', params: {
        'p_booking_id': bookingId,
        'p_additional_minutes': additionalMinutes,
        'p_additional_cost': additionalCost,
      });
      dev.log("[LIVESESSION_DS] EXTEND_TIME RPC SUCCESS");
    } catch (e1) {
      dev.log("[LIVESESSION_DS] EXTEND_TIME RPC fallback 1 error: $e1");
      try {
        await _client.rpc('extend_active_session', params: {
          'booking_id': bookingId,
          'additional_minutes': additionalMinutes,
          'additional_cost': additionalCost,
        });
        dev.log("[LIVESESSION_DS] EXTEND_TIME RPC 2 SUCCESS");
      } catch (e2) {
        dev.log("[LIVESESSION_DS] EXTEND_TIME RPC fallback 2 error: $e2");
        try {
          await _client.rpc('extend_booking_session', params: {
            'p_booking_id': bookingId,
            'p_additional_minutes': additionalMinutes,
            'p_added_cost': additionalCost,
          });
          dev.log("[LIVESESSION_DS] EXTEND_BOOKING_SESSION RPC SUCCESS");
        } catch (e3) {
          dev.log("[LIVESESSION_DS] EXTEND_TIME Direct DB update fallback...");
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
          dev.log("[LIVESESSION_DS] EXTEND_TIME Direct DB update SUCCESS");
        }
      }
    }
  }

  @override
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    dev.log("[LIVESESSION_DS] REQUEST_EXTENSION: bookingId=$bookingId, requestedMinutes=$requestedMinutes");
    await _client.from('bookings').update({
      'extension_status': 'pending',
      'requested_extension_minutes': requestedMinutes,
    }).eq('id', bookingId);
    dev.log("[LIVESESSION_DS] REQUEST_EXTENSION SUCCESS");
  }

  @override
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items) async {
    dev.log("[LIVESESSION_DS] PLACE_ORDER: bookingId=$bookingId, itemsCount=${items.length}");
    try {
      for (final item in items) {
        final payload = {
          'booking_id': bookingId,
          'item_id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'note': item.note,
        };
        dev.log("[LIVESESSION_DS] Placing order item payload: $payload");

        try {
          // Attempt 1: Call 'add_session_extra' RPC with 'p_' prefixed params
          await _client.rpc('add_session_extra', params: {
            'p_booking_id': bookingId,
            'p_extra_id': item.id,
            'p_item_id': item.id,
            'p_name': item.name,
            'p_quantity': item.quantity,
            'p_price': item.price,
            'p_notes': item.note,
            'p_note': item.note,
          });
          dev.log("[LIVESESSION_DS] ADD_SESSION_EXTRA RPC SUCCESS for ${item.name}");
        } catch (e1, st1) {
          dev.log("[LIVESESSION_DS] RPC add_session_extra (p_ params) failed: $e1", error: e1, stackTrace: st1);

          try {
            // Attempt 2: Call 'add_session_extra' RPC without 'p_' prefix
            await _client.rpc('add_session_extra', params: {
              'booking_id': bookingId,
              'extra_id': item.id,
              'item_id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
              'note': item.note,
              'notes': item.note,
            });
            dev.log("[LIVESESSION_DS] ADD_SESSION_EXTRA RPC 2 SUCCESS for ${item.name}");
          } catch (e2, st2) {
            dev.log("[LIVESESSION_DS] RPC add_session_extra (standard params) failed: $e2", error: e2, stackTrace: st2);

            try {
              // Attempt 3: Direct insert into 'booking_items' table
              await _client.from('booking_items').insert(payload);
              dev.log("[LIVESESSION_DS] Direct booking_items insert SUCCESS for ${item.name}");
            } catch (e3, st3) {
              dev.log("[LIVESESSION_DS] Direct booking_items insert failed: $e3", error: e3, stackTrace: st3);

              try {
                // Attempt 4: Direct insert into 'canteen_orders' table
                await _client.from('canteen_orders').insert(payload);
                dev.log("[LIVESESSION_DS] Direct canteen_orders insert SUCCESS for ${item.name}");
              } catch (e4, st4) {
                dev.log("[LIVESESSION_DS] All order placement methods failed for ${item.name}: $e4", error: e4, stackTrace: st4);
                rethrow;
              }
            }
          }
        }
      }
    } catch (e, st) {
      dev.log("[LIVESESSION_DS] PLACE_ORDER FAILED: $e", error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<ExtraModel>> getLoungeMenu(String loungeId) async {
    dev.log("[LIVESESSION_DS] GET_LOUNGE_MENU: loungeId=$loungeId");
    try {
      final response = await _client
          .from('extras')
          .select()
          .eq('lounge_id', loungeId);

      final menu = (response as List).map((e) => ExtraModel.fromJson(e)).toList();
      dev.log("[LIVESESSION_DS] GET_LOUNGE_MENU SUCCESS: ${menu.length} items");
      return menu;
    } catch (e) {
      dev.log("[LIVESESSION_DS] GET_LOUNGE_MENU ERROR: $e");
      return [];
    }
  }

  @override
  Future<void> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  }) async {
    dev.log("[LIVESESSION_DS] REQUEST_STAFF_ASSISTANCE: bookingId=$bookingId, callType=$callType, notes=$notes");
    final userId = _client.auth.currentUser?.id;
    await _client.rpc('request_staff_assistance', params: {
      'p_booking_id': bookingId,
      'p_user_id': userId,
      'p_call_type': callType,
      'p_notes': notes,
    });
    dev.log("[LIVESESSION_DS] REQUEST_STAFF_ASSISTANCE SUCCESS");
  }

  @override
  Future<void> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    dev.log("[LIVESESSION_DS] SUBMIT_LOUNGE_REVIEW: loungeId=$loungeId, bookingId=$bookingId, rating=$rating, comment=$comment");
    final userId = _client.auth.currentUser?.id;

    // 1. Try RPC with p_ params
    try {
      await _client.rpc('submit_lounge_review', params: {
        'p_lounge_id': loungeId,
        'p_booking_id': bookingId,
        'p_user_id': userId,
        'p_rating': rating,
        'p_comment': comment,
      });
      dev.log("[LIVESESSION_DS] SUBMIT_LOUNGE_REVIEW RPC (p_ params) SUCCESS");
    } catch (e1) {
      dev.log("[LIVESESSION_DS] submit_lounge_review RPC (p_ params) failed: $e1");

      // 2. Try RPC without p_ params
      try {
        await _client.rpc('submit_lounge_review', params: {
          'lounge_id': loungeId,
          'booking_id': bookingId,
          'user_id': userId,
          'rating': rating,
          'comment': comment,
        });
        dev.log("[LIVESESSION_DS] SUBMIT_LOUNGE_REVIEW RPC (standard params) SUCCESS");
      } catch (e2) {
        dev.log("[LIVESESSION_DS] submit_lounge_review RPC (standard params) failed: $e2");
      }
    }

    // 3. Fallback / Direct persistence to guarantee review appears on Lounge Details page:
    // Insert/upsert to 'lounge_reviews'
    try {
      await _client.from('lounge_reviews').upsert({
        'lounge_id': loungeId,
        'booking_id': bookingId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });
      dev.log("[LIVESESSION_DS] Direct insert to lounge_reviews SUCCESS");
    } catch (e3) {
      dev.log("[LIVESESSION_DS] Direct insert to lounge_reviews failed: $e3");
    }

    // Insert/upsert to 'reviews'
    try {
      await _client.from('reviews').upsert({
        'lounge_id': loungeId,
        'booking_id': bookingId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });
      dev.log("[LIVESESSION_DS] Direct insert to reviews SUCCESS");
    } catch (e4) {
      dev.log("[LIVESESSION_DS] Direct insert to reviews failed: $e4");
    }

    // Update 'bookings' table directly as well
    try {
      await _client.from('bookings').update({
        'rating': rating,
        'comment': comment,
        'review': comment,
      }).eq('id', bookingId);
      dev.log("[LIVESESSION_DS] Direct update to bookings table SUCCESS");
    } catch (e5) {
      dev.log("[LIVESESSION_DS] Direct update to bookings table failed: $e5");
    }
  }
}
