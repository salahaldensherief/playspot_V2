import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/play_spot_live_activity_service.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/core/mixins/realtime_watcher_mixin.dart';
import '../../../../core/constants/booking_status.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/native_notification_service.dart';
import '../domain/repositories/active_session_repository.dart';
import '../data/models/order_item_model.dart';
import 'active_session_state.dart';

class ActiveSessionCubit extends Cubit<ActiveSessionState> with RealtimeWatcherMixin {
  final ActiveSessionRepository _repo;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _userSessionsSubscription;
  String? _subscribedBookingId;

  ActiveSessionCubit(this._repo) : super(const ActiveSessionState()) {
    _watchUserSessions();
  }

  void _watchUserSessions() {
    _userSessionsSubscription?.cancel();
    _userSessionsSubscription = subscribeWithRetry(
      streamFactory: () => _repo.watchUserActiveSession(),
      onData: (activeSession) {
        if (activeSession != null) {
          dev.log("[LIVESESSION_CUBIT] Watch Stream detected active session: ${activeSession.bookingId}");
          if (state.session == null || state.session!.bookingId != activeSession.bookingId || state.status != ActiveSessionStatus.loaded) {
            loadActiveSession(bookingId: activeSession.bookingId);
          }
        }
      },
      onError: (err) {
        dev.log("[LIVESESSION_CUBIT] WATCH USER SESSIONS STREAM ERROR: $err");
      },
      isClosedCheck: () => isClosed,
      retryDelay: const Duration(seconds: 5),
      tag: 'LIVESESSION_WATCH_USER',
    );
  }

  /// Calculates pre-calculated extension cost based on active session rates
  double calculateExtensionCost(int additionalMinutes) {
    final session = state.session ?? state.completedSession;
    if (session == null) return 0.0;
    return session.calculateExtensionCost(additionalMinutes);
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
          LocalNotificationService.instance.cancelActiveSessionNotification();
          NativeNotificationService.instance.cancelCustomNotification();
          PlaySpotLiveActivityService.instance.endActivity();
          emit(state.copyWith(
            status: ActiveSessionStatus.empty,
            session: null,
            completedSession: state.session ?? state.completedSession,
          ));
        } else {
          dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION LOADED: bookingId=${session.bookingId}, status=${session.status}");
          emit(state.copyWith(
            status: ActiveSessionStatus.loaded,
            session: session,
          ));
          _subscribeToRealtime(session.bookingId);
          loadMenu(session.loungeId);

          try {
            PlaySpotLiveActivityService.instance.startActivity(
              sessionId: session.bookingId,
              hallName: session.loungeName.isNotEmpty ? session.loungeName : 'PlaySpot Lounge',
              deviceName: session.deviceName.isNotEmpty ? session.deviceName : session.roomName,
              endTimeTimestamp: session.endTime.millisecondsSinceEpoch ~/ 1000,
            );

            final notificationId = session.bookingId.hashCode.abs() & 0x7FFFFFFF;
            LocalNotificationService.instance.scheduleSessionExpiryWarning(
              id: notificationId,
              loungeName: session.loungeName.isNotEmpty ? session.loungeName : 'Lounge',
              expiryTime: session.endTime,
            );

            final now = DateTime.now();
            final remaining = session.endTime.difference(now);
            final hours = remaining.inHours;
            final mins = remaining.inMinutes % 60;
            final timeText = hours > 0 ? '$hours h $mins m remaining' : '$mins mins remaining';

            NativeNotificationService.instance.showCustomNotification(
              loungeName: session.loungeName.isNotEmpty ? session.loungeName : 'Active Session',
              deviceName: session.deviceName.isNotEmpty ? session.deviceName : session.roomName,
              timeText: timeText,
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

    _realtimeSubscription = subscribeWithRetry(
      streamFactory: () => _repo.streamActiveSession(bookingId),
      onData: (updatedSession) {
        dev.log("[LIVESESSION_CUBIT] REALTIME EVENT for $bookingId: status=${updatedSession.status}, end_time=${updatedSession.endTime}");
        final status = BookingStatus.fromString(updatedSession.status);
        if (status == BookingStatus.completed || status == BookingStatus.cancelled) {
          dev.log("[LIVESESSION_CUBIT] Session ended or cancelled via Realtime");
          _subscribedBookingId = null;
          _realtimeSubscription?.cancel();
          _realtimeSubscription = null;
          LocalNotificationService.instance.cancelActiveSessionNotification();
          NativeNotificationService.instance.cancelCustomNotification();
          PlaySpotLiveActivityService.instance.endActivity();
          emit(state.copyWith(
            status: ActiveSessionStatus.empty,
            session: null,
            completedSession: state.session ?? updatedSession,
          ));
        } else {
          dev.log("[LIVESESSION_CUBIT] Realtime update applied directly without re-fetching...");
          final currentSession = state.session;
          final mergedSession = updatedSession.copyWith(
            loungeName: updatedSession.loungeName.isNotEmpty
                ? updatedSession.loungeName
                : currentSession?.loungeName ?? '',
            roomName: updatedSession.roomName.isNotEmpty
                ? updatedSession.roomName
                : currentSession?.roomName ?? '',
            orders: updatedSession.orders.isNotEmpty
                ? updatedSession.orders
                : currentSession?.orders ?? const [],
          );

          emit(state.copyWith(
            status: ActiveSessionStatus.loaded,
            session: mergedSession,
          ));

          try {
            PlaySpotLiveActivityService.instance.startActivity(
              sessionId: mergedSession.bookingId,
              hallName: mergedSession.loungeName.isNotEmpty ? mergedSession.loungeName : 'PlaySpot Lounge',
              deviceName: mergedSession.deviceName.isNotEmpty ? mergedSession.deviceName : mergedSession.roomName,
              endTimeTimestamp: mergedSession.endTime.millisecondsSinceEpoch ~/ 1000,
            );

            final notificationId = mergedSession.bookingId.hashCode.abs() & 0x7FFFFFFF;
            LocalNotificationService.instance.scheduleSessionExpiryWarning(
              id: notificationId,
              loungeName: mergedSession.loungeName.isNotEmpty ? mergedSession.loungeName : 'Lounge',
              expiryTime: mergedSession.endTime,
            );
          } catch (_) {}
        }
      },
      onError: (err) {
        dev.log("[LIVESESSION_CUBIT] REALTIME STREAM ERROR: $err");
        _subscribedBookingId = null;
      },
      isClosedCheck: () => isClosed || (_subscribedBookingId != null && _subscribedBookingId != bookingId),
      retryDelay: const Duration(seconds: 3),
      tag: 'LIVESESSION_REALTIME',
    );
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

  Future<void> extendTime(int additionalMinutes, [double? precalculatedCost]) async {
    final active = state.session;
    if (active == null) return;

    HapticFeedback.mediumImpact();

    final cost = precalculatedCost ?? calculateExtensionCost(additionalMinutes);
    final bookingId = active.bookingId;
    dev.log("[LIVESESSION_CUBIT] EXTEND_TIME: bookingId=$bookingId, minutes=$additionalMinutes, cost=$cost");

    emit(state.copyWith(extendStatus: ActionStatus.loading));

    final result = await _repo.extendTime(bookingId, additionalMinutes, cost);

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

    HapticFeedback.mediumImpact();

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
    final session = state.session ?? state.completedSession;
    if (session == null) return;

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    dev.log("[LIVESESSION_CUBIT] SUBMIT_REVIEW: bookingId=$bookingId, rating=$rating");

    final result = await _repo.submitLoungeReview(
      loungeId: session.loungeId,
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
        try {
          sl<ProfileCubit>().getUserData();
        } catch (_) {}
        emit(state.copyWith(
          status: ActiveSessionStatus.empty,
          session: null,
          completedSession: null,
        ));
      },
    );
  }

  Future<void> placeOrder(List<OrderItemModel> items) async {
    if (state.session == null) return;

    HapticFeedback.mediumImpact();

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
