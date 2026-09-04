import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/booking_status.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../domain/repositories/active_session_repository.dart';
import '../data/models/order_item_model.dart';
import 'active_session_state.dart';

class ActiveSessionCubit extends Cubit<ActiveSessionState> {
  final ActiveSessionRepository _repo;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _userSessionsSubscription;
  String? _subscribedBookingId;

  ActiveSessionCubit(this._repo) : super(const ActiveSessionState()) {
    _watchUserSessions();
  }

  void _watchUserSessions() {
    _userSessionsSubscription?.cancel();
    _userSessionsSubscription = _repo.watchUserActiveSession().listen((activeSession) {
      if (activeSession != null) {
        dev.log("[LIVESESSION_CUBIT] Watch Stream detected active session: ${activeSession.bookingId}");
        if (state.session == null || state.session!.bookingId != activeSession.bookingId || state.status != ActiveSessionStatus.loaded) {
          loadActiveSession(bookingId: activeSession.bookingId);
        }
      }
    });
  }

  Future<void> loadActiveSession({String? bookingId}) async {
    dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION: bookingId=$bookingId");
    if (state.status != ActiveSessionStatus.loaded) {
      emit(state.copyWith(status: ActiveSessionStatus.loading));
    }

    final result = await _repo.getActiveSession(bookingId: bookingId);

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION FAILURE: ${failure.message}");
        emit(state.copyWith(
          status: ActiveSessionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (session) {
        if (session == null) {
          dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION EMPTY: No session found");
          _subscribedBookingId = null;
          _realtimeSubscription?.cancel();
          _realtimeSubscription = null;
          emit(state.copyWith(status: ActiveSessionStatus.empty, session: null));
        } else {
          dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION LOADED: bookingId=${session.bookingId}, status=${session.status}");
          emit(state.copyWith(
            status: ActiveSessionStatus.loaded,
            session: session,
          ));
          _subscribeToRealtime(session.bookingId);
          loadMenu(session.loungeId);

          try {
            final notificationId = session.bookingId.hashCode.abs() & 0x7FFFFFFF;
            LocalNotificationService.instance.scheduleSessionExpiryWarning(
              id: notificationId,
              loungeName: session.loungeName.isNotEmpty ? session.loungeName : 'Lounge',
              expiryTime: session.endTime,
            );
          } catch (_) {}
        }
      },
    );
  }

  void _subscribeToRealtime(String bookingId) {
    if (_subscribedBookingId == bookingId && _realtimeSubscription != null) {
      return;
    }

    dev.log("[LIVESESSION_CUBIT] Subscribing to Realtime stream for booking: $bookingId");
    _subscribedBookingId = bookingId;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repo.streamActiveSession(bookingId).listen((updatedSession) {
      dev.log("[LIVESESSION_CUBIT] REALTIME EVENT for $bookingId: status=${updatedSession.status}, end_time=${updatedSession.endTime}");
      final status = BookingStatus.fromString(updatedSession.status);
      if (status == BookingStatus.completed || status == BookingStatus.cancelled) {
        dev.log("[LIVESESSION_CUBIT] Session ended or cancelled via Realtime");
        _subscribedBookingId = null;
        _realtimeSubscription?.cancel();
        _realtimeSubscription = null;
        emit(state.copyWith(status: ActiveSessionStatus.empty, session: null));
      } else {
        dev.log("[LIVESESSION_CUBIT] Re-fetching active session details after Realtime event...");
        loadActiveSession(bookingId: bookingId);
      }
    }, onError: (err) {
      dev.log("[LIVESESSION_CUBIT] REALTIME STREAM ERROR: $err");
      loadActiveSession(bookingId: bookingId);
    });
  }

  Future<void> loadMenu(String loungeId) async {
    if (loungeId.isEmpty || isClosed) return;
    dev.log("[LIVESESSION_CUBIT] LOAD_MENU for lounge: $loungeId");
    final result = await _repo.getLoungeMenu(loungeId);
    if (isClosed) return;
    result.fold(
      (f) => dev.log("[LIVESESSION_CUBIT] LOAD_MENU FAILURE: ${f.message}"),
      (menu) {
        dev.log("[LIVESESSION_CUBIT] LOAD_MENU SUCCESS: ${menu.length} items");
        emit(state.copyWith(menu: menu));
      },
    );
  }

  Future<void> extendTime(int additionalMinutes, double cost) async {
    if (state.session == null) return;
    final bookingId = state.session!.bookingId;
    dev.log("[LIVESESSION_CUBIT] EXTEND_TIME: bookingId=$bookingId, minutes=$additionalMinutes, cost=$cost");

    emit(state.copyWith(extendStatus: ActionStatus.loading));

    final result = await _repo.requestExtension(
      bookingId: bookingId,
      requestedMinutes: additionalMinutes,
    );

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] EXTEND_TIME FAILURE: ${failure.message}");
        emit(state.copyWith(
          extendStatus: ActionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] EXTEND_TIME SUCCESS");
        emit(state.copyWith(extendStatus: ActionStatus.success));
        loadActiveSession(bookingId: bookingId);
      },
    );
  }

  Future<void> requestStaffAssistance(String type, String? notes) async {
    if (state.session == null) return;
    final bookingId = state.session!.bookingId;
    dev.log("[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE: bookingId=$bookingId, type=$type");

    emit(state.copyWith(staffRequestStatus: ActionStatus.loading));

    final result = await _repo.requestStaffAssistance(
      bookingId: bookingId,
      callType: type,
      notes: notes,
    );

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE FAILURE: ${failure.message}");
        emit(state.copyWith(
          staffRequestStatus: ActionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE SUCCESS");
        emit(state.copyWith(staffRequestStatus: ActionStatus.success));
      },
    );
  }

  Future<void> submitReview({
    required double rating,
    String? comment,
  }) async {
    if (state.session == null) return;
    final bookingId = state.session!.bookingId;
    dev.log("[LIVESESSION_CUBIT] SUBMIT_REVIEW: bookingId=$bookingId, rating=$rating");

    final result = await _repo.submitLoungeReview(
      loungeId: state.session!.loungeId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] SUBMIT_REVIEW FAILURE: ${failure.message}");
        emit(state.copyWith(errorMessage: failure.message));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] SUBMIT_REVIEW SUCCESS");
        emit(state.copyWith(
          status: ActiveSessionStatus.empty,
          session: null,
        ));
      },
    );
  }

  Future<void> placeOrder(List<OrderItemModel> items) async {
    if (state.session == null) return;
    final bookingId = state.session!.bookingId;
    dev.log("[LIVESESSION_CUBIT] PLACE_ORDER: bookingId=$bookingId, itemsCount=${items.length}");

    emit(state.copyWith(orderStatus: ActionStatus.loading));

    final result = await _repo.placeOrder(bookingId, items);

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] PLACE_ORDER FAILURE: ${failure.message}");
        emit(state.copyWith(
          orderStatus: ActionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] PLACE_ORDER SUCCESS");
        emit(state.copyWith(orderStatus: ActionStatus.success));
        loadActiveSession(bookingId: bookingId);
      },
    );
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    _userSessionsSubscription?.cancel();
    return super.close();
  }
}
