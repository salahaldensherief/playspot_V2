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
      try {
        final response = await _client
            .from('bookings')
            .select(selectQuery)
            .eq('id', bookingId)
            .maybeSingle();

        if (response == null) return null;
        final model = ActiveSessionModel.fromJson(Map<String, dynamic>.from(response));
        dev.log("[LIVESESSION_DS] GET_ACTIVE_SESSION SUCCESS: bookingId=${model.bookingId}, status=${model.status}");
        return model;
      } catch (e) {
        dev.log("[LIVESESSION_DS] Fetching specific booking $bookingId error: $e");
        return null;
      }
    }

    // 2. Fetch active in_progress session ONLY
    dev.log("[LIVESESSION_DS] Fetching active in_progress session...");
    try {
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
    } catch (e) {
      dev.log("[LIVESESSION_DS] Fetching active in_progress session error: $e");
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
    dev.log(
      "[LIVESESSION_DS] REQUEST_EXTENSION: bookingId=$bookingId, requestedMinutes=$requestedMinutes",
    );

    await _client.rpc(
      'request_booking_extension',
      params: {
        'p_booking_id': bookingId,
        'p_requested_minutes': requestedMinutes,
      },
    );
  }

  @override
  Future<void> placeOrder(
    String bookingId,
    List<OrderItemModel> items,
  ) async {
    if (items.isEmpty) return;

    final formattedItems = items
        .map(
          (item) => {
            'extra_id': item.id,
            'quantity': item.quantity,
          },
        )
        .toList();

    final notes = items
        .where((item) => item.note != null && item.note!.trim().isNotEmpty)
        .map((item) => item.note!.trim())
        .join(', ');

    await _client.rpc(
      'place_canteen_order',
      params: {
        'p_booking_id': bookingId,
        'p_items': formattedItems,
        if (notes.isNotEmpty) 'p_note': notes,
      },
    );
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
    await _client.rpc(
      'request_staff_assistance_for_booking',
      params: {
        'p_booking_id': bookingId,
        'p_call_type': callType,
        'p_notes': notes,
      },
    );
  }

  @override
  Future<void> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    await _client.rpc(
      'submit_lounge_review',
      params: {
        'p_lounge_id': loungeId,
        'p_booking_id': bookingId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );
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
