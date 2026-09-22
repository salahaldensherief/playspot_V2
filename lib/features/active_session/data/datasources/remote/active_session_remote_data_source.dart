import 'dart:async';
import 'dart:developer' as dev;
import 'package:playspot/core/models/paginated_response.dart';
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
  Future<PaginatedResponse<Map<String, dynamic>>> getActiveLoungeRequestsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
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

    const selectQuery = '*, lounges(name), rooms(name, name_en), booking_items(*), canteen_orders(*, canteen_order_items(*))';
    final now = DateTime.now();

    // Try RPC get_active_session_details first for rich hydrated session details
    try {
      final rpcRes = await _client.rpc('get_active_session_details', params: {
        if (bookingId != null && bookingId.isNotEmpty) 'p_booking_id': bookingId,
      });
      if (rpcRes != null) {
        final Map<String, dynamic> rpcMap = rpcRes is List
            ? (rpcRes.isNotEmpty ? Map<String, dynamic>.from(rpcRes.first) : {})
            : Map<String, dynamic>.from(rpcRes);
        if (rpcMap.isNotEmpty && rpcMap['id'] != null) {
          final rpcModel = ActiveSessionModel.fromJson(rpcMap);
          if (rpcModel.bookingId.isNotEmpty && rpcModel.status == 'in_progress') {
            dev.log("[LIVESESSION_DS] GET_ACTIVE_SESSION RPC SUCCESS: bookingId=${rpcModel.bookingId}");
            return rpcModel;
          }
        }
      }
    } catch (e) {
      dev.log("[LIVESESSION_DS] RPC get_active_session_details failed: $e, falling back to selectQuery");
    }

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
      if (model.status != 'in_progress') {
        dev.log("[LIVESESSION_DS] Booking is not active/in_progress (status=${model.status})");
        return null;
      }
      dev.log("[LIVESESSION_DS] GET_ACTIVE_SESSION SUCCESS: bookingId=${model.bookingId}");
      return model;
    }

    // 2. Fetch active in_progress session ONLY
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
      final isExpired = now.isAfter(activeModel.endTime.add(const Duration(minutes: 5)));
      if (!isExpired) {
        dev.log("[LIVESESSION_DS] Found active in_progress session: ${activeModel.bookingId}");
        return activeModel;
      }
    }

    dev.log("[LIVESESSION_DS] No active session found");
    return null;
  }

  @override
  Stream<ActiveSessionModel> streamActiveSession(String bookingId) {
    dev.log("[LIVESESSION_DS] STREAM_ACTIVE_SESSION: bookingId=$bookingId");
    final controller = StreamController<ActiveSessionModel>.broadcast();
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      try {
        final fullSession = await getActiveSession(bookingId: bookingId);
        if (fullSession != null && !controller.isClosed) {
          controller.add(fullSession);
        }
      } catch (e) {
        dev.log("[LIVESESSION_DS] Error fetching active session in stream for $bookingId: $e");
      }
    }

    fetchAndEmit();

    try {
      channel = _client.channel('booking_$bookingId');

      channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) {
            dev.log("[LIVESESSION_DS] Realtime change on 'bookings' for $bookingId: ${payload.eventType}");
            fetchAndEmit();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'canteen_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) {
            dev.log("[LIVESESSION_DS] Realtime change on 'canteen_orders' for $bookingId: ${payload.eventType}");
            fetchAndEmit();
          },
        )
        .subscribe((status, [error]) {
          dev.log("[LIVESESSION_DS] Realtime channel booking_$bookingId status: $status ${error ?? ''}");
        });
    } catch (e) {
      dev.log("[LIVESESSION_DS] Error initializing channel booking_$bookingId: $e");
    }

    controller.onCancel = () {
      dev.log("[LIVESESSION_DS] Closing channel booking_$bookingId");
      if (channel != null) {
        _client.removeChannel(channel);
      }
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<ActiveSessionModel?> watchUserActiveSession() {
    dev.log("[LIVESESSION_DS] WATCH_USER_ACTIVE_SESSION");
    final controller = StreamController<ActiveSessionModel?>.broadcast();
    RealtimeChannel? bookingChannel;
    RealtimeChannel? userBookingsChannel;
    String? currentBookingId;

    Future<void> syncSession() async {
      try {
        final session = await getActiveSession();
        if (controller.isClosed) return;
        controller.add(session);

        if (session != null && session.bookingId != currentBookingId) {
          currentBookingId = session.bookingId;
          if (bookingChannel != null) {
            _client.removeChannel(bookingChannel!);
            bookingChannel = null;
          }

          bookingChannel = _client.channel('booking_${session.bookingId}');
          bookingChannel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'bookings',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: session.bookingId,
              ),
              callback: (payload) {
                dev.log("[LIVESESSION_DS] Realtime user booking update for ${session.bookingId}: ${payload.eventType}");
                syncSession();
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'canteen_orders',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'booking_id',
                value: session.bookingId,
              ),
              callback: (payload) {
                dev.log("[LIVESESSION_DS] Realtime user canteen_orders update for ${session.bookingId}: ${payload.eventType}");
                syncSession();
              },
            )
            .subscribe();
        } else if (session == null && bookingChannel != null) {
          currentBookingId = null;
          _client.removeChannel(bookingChannel!);
          bookingChannel = null;
        }
      } catch (e) {
        dev.log("[LIVESESSION_DS] Error in watchUserActiveSession sync: $e");
      }
    }

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      userBookingsChannel = _client.channel('user_bookings_$userId');
      userBookingsChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => syncSession(),
        )
        .subscribe();
    }

    syncSession();

    controller.onCancel = () {
      final bChannel = bookingChannel;
      if (bChannel != null) {
        _client.removeChannel(bChannel);
      }
      final uChannel = userBookingsChannel;
      if (uChannel != null) {
        _client.removeChannel(uChannel);
      }
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    dev.log("[LIVESESSION_DS] EXTEND_TIME: bookingId=$bookingId, minutes=$additionalMinutes, cost=$additionalCost");
    try {
      await _client.rpc('extend_booking_session', params: {
        'p_booking_id': bookingId,
        'p_additional_minutes': additionalMinutes,
        'p_additional_cost': additionalCost,
      });
      dev.log("[LIVESESSION_DS] EXTEND_BOOKING_SESSION RPC SUCCESS");
    } catch (e) {
      dev.log("[LIVESESSION_DS] EXTEND_BOOKING_SESSION RPC error: $e");
      final errorStr = e.toString();
      if (errorStr.contains('BOOKING_EXTENSION_CONFLICT') ||
          errorStr.contains('conflict') ||
          errorStr.contains('23P01') ||
          errorStr.contains('exclusion constraint')) {
        throw Exception("لا يمكن تمديد الحجز لأن هناك حجزاً آخر يبدأ بعد وقت حجزك مباشرة.");
      }
      rethrow;
    }
  }

  @override
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    dev.log("[LIVESESSION_DS] REQUEST_EXTENSION: bookingId=$bookingId, requestedMinutes=$requestedMinutes");
    try {
      await _client.rpc('request_booking_extension', params: {
        'p_booking_id': bookingId,
        'p_requested_minutes': requestedMinutes,
      });
      dev.log("[LIVESESSION_DS] REQUEST_BOOKING_EXTENSION RPC SUCCESS");
    } catch (e) {
      dev.log("[LIVESESSION_DS] request_booking_extension RPC failed: $e, checking error or fallback...");
      final errorStr = e.toString();
      if (errorStr.contains('BOOKING_CONFLICT') ||
          errorStr.contains('conflict') ||
          errorStr.contains('محجوزة')) {
        throw Exception("لا يمكن تمديد الوقت لأن الغرفة محجوزة لحجز قادم بعد وقتك مباشرة.");
      }

      await _client.from('bookings').update({
        'extension_status': 'pending',
        'requested_extension_minutes': requestedMinutes,
        'extension_minutes': requestedMinutes,
      }).eq('id', bookingId);
      dev.log("[LIVESESSION_DS] Fallback update to bookings SUCCESS");
    }
  }

  @override
  Future<void> placeOrder(String bookingId, List<OrderItemModel> items) async {
    dev.log("[LIVESESSION_DS] PLACE_ORDER (Canteen): bookingId=$bookingId, itemsCount=${items.length}");
    try {
      if (items.isEmpty) return;

      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final formattedItems = items.map((item) {
        return {
          'id': item.id,
          'name_ar': item.nameAr ?? item.name,
          'name_en': item.nameEn ?? item.name,
          'unit_price': item.price,
          'quantity': item.quantity,
          if (item.note != null && item.note!.isNotEmpty) 'note': item.note,
        };
      }).toList();

      final notes = items.where((i) => i.note != null && i.note!.isNotEmpty).map((i) => i.note).join(', ');

      try {
        final response = await _client.rpc('place_canteen_order', params: {
          'p_booking_id': bookingId,
          'p_items': formattedItems,
          if (notes.isNotEmpty) 'p_note': notes,
        });
        dev.log("[LIVESESSION_DS] PLACE_CANTEEN_ORDER RPC SUCCESS: $response");
      } catch (e) {
        dev.log("[LIVESESSION_DS] place_canteen_order with p_booking_id and p_items failed: $e, trying full params...");
        final bookingRes = await _client
            .from('bookings')
            .select('lounge_id')
            .eq('id', bookingId)
            .maybeSingle();
        final loungeId = bookingRes?['lounge_id']?.toString() ?? '';

        final response = await _client.rpc('place_canteen_order', params: {
          'p_booking_id': bookingId,
          'p_lounge_id': loungeId.isNotEmpty ? loungeId : null,
          'p_user_id': currentUserId,
          'p_items': formattedItems,
          'p_total_price': null,
          'p_note': notes.isNotEmpty ? notes : null,
        });
        dev.log("[LIVESESSION_DS] PLACE_CANTEEN_ORDER RPC with full params SUCCESS: $response");
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

    final bookingData = await _client
        .from('bookings')
        .select('lounge_id, room_id, user_id')
        .eq('id', bookingId)
        .maybeSingle();

    final String? loungeId = bookingData?['lounge_id']?.toString();
    final String? roomId = bookingData?['room_id']?.toString();
    final String? bookingUserId = bookingData?['user_id']?.toString() ?? userId;

    try {
      await _client.rpc('request_staff_assistance', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
        'p_call_type': callType,
        'p_notes': notes,
        if (loungeId != null && loungeId.isNotEmpty) 'p_lounge_id': loungeId,
        if (roomId != null && roomId.isNotEmpty) 'p_room_id': roomId,
      });
      dev.log("[LIVESESSION_DS] REQUEST_STAFF_ASSISTANCE via RPC success");
      return;
    } catch (rpc1Error) {
      dev.log("[LIVESESSION_DS] RPC request_staff_assistance failed: $rpc1Error, trying call_staff_request");
    }

    try {
      await _client.rpc('call_staff_request', params: {
        'p_booking_id': bookingId,
        if (loungeId != null && loungeId.isNotEmpty) 'p_lounge_id': loungeId,
        'p_reason': callType,
        'p_note': notes ?? '',
      });
      dev.log("[LIVESESSION_DS] CALL_STAFF_REQUEST via RPC success");
      return;
    } catch (rpc2Error) {
      dev.log("[LIVESESSION_DS] RPC call_staff_request failed: $rpc2Error, inserting directly into service_calls");
    }

    try {
      await _client.from('service_calls').insert({
        'booking_id': bookingId,
        if (loungeId != null && loungeId.isNotEmpty) 'lounge_id': loungeId,
        if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
        if (bookingUserId != null && bookingUserId.isNotEmpty) 'user_id': bookingUserId,
        'call_type': callType,
        'request_type': callType,
        'status': 'pending',
        'is_attended': false,
        if (notes != null && notes.isNotEmpty) 'note': notes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      dev.log("[LIVESESSION_DS] Inserted directly into service_calls SUCCESS");
    } catch (insertError) {
      dev.log("[LIVESESSION_DS] Direct insert into service_calls failed: $insertError");
      rethrow;
    }
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

  @override
  Future<PaginatedResponse<Map<String, dynamic>>> getActiveLoungeRequestsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.rpc('get_active_lounge_requests_page', params: {
        'p_lounge_id': loungeId,
        'p_page': page,
        'p_page_size': pageSize,
      });

      return PaginatedResponse.fromRpc(
        response: response,
        fromJson: (json) => json,
        requestedPage: page,
        requestedPageSize: pageSize,
      );
    } catch (e) {
      dev.log("[LIVESESSION_DS] get_active_lounge_requests_page error: $e");
      return PaginatedResponse(
        items: const [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
    }
  }
}
