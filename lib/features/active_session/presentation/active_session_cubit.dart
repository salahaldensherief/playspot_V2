import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/play_spot_live_activity_service.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/core/mixins/realtime_watcher_mixin.dart';
import '../../../../core/constants/booking_status.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/native_notification_service.dart';
import '../domain/entities/active_session.dart';
import '../domain/entities/order_item.dart';
import '../domain/usecases/extend_session_time_usecase.dart';
import '../domain/usecases/get_active_session_usecase.dart';
import '../domain/usecases/get_lounge_menu_usecase.dart';
import '../domain/usecases/place_session_order_usecase.dart';
import '../domain/usecases/request_session_extension_usecase.dart';
import '../domain/usecases/request_staff_assistance_usecase.dart';
import '../domain/usecases/stream_active_session_usecase.dart';
import '../domain/usecases/submit_lounge_review_usecase.dart';
import '../domain/usecases/watch_user_active_session_usecase.dart';
import 'active_session_state.dart';
import 'widgets/lounge_review_bottom_sheet.dart';
import '../../../../art_core/router/app_router.dart';
import '../../../../art_core/widgets/layout/app_bottom_sheet.dart';
import 'package:get_storage/get_storage.dart';
import '../../../../core/cache/caching_key.dart';

class ActiveSessionCubit extends Cubit<ActiveSessionState> with RealtimeWatcherMixin {
  final GetActiveSessionUseCase _getActiveSessionUseCase;
  final WatchUserActiveSessionUseCase _watchUserActiveSessionUseCase;
  final StreamActiveSessionUseCase _streamActiveSessionUseCase;
  final ExtendSessionTimeUseCase _extendSessionTimeUseCase;
  final RequestSessionExtensionUseCase _requestSessionExtensionUseCase;
  final PlaceSessionOrderUseCase _placeSessionOrderUseCase;
  final GetLoungeMenuUseCase _getLoungeMenuUseCase;
  final RequestStaffAssistanceUseCase _requestStaffAssistanceUseCase;
  final SubmitLoungeReviewUseCase _submitLoungeReviewUseCase;

  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _userSessionsSubscription;
  String? _subscribedBookingId;

  ActiveSessionCubit({
    required GetActiveSessionUseCase getActiveSessionUseCase,
    required WatchUserActiveSessionUseCase watchUserActiveSessionUseCase,
    required StreamActiveSessionUseCase streamActiveSessionUseCase,
    required ExtendSessionTimeUseCase extendSessionTimeUseCase,
    required RequestSessionExtensionUseCase requestSessionExtensionUseCase,
    required PlaceSessionOrderUseCase placeSessionOrderUseCase,
    required GetLoungeMenuUseCase getLoungeMenuUseCase,
    required RequestStaffAssistanceUseCase requestStaffAssistanceUseCase,
    required SubmitLoungeReviewUseCase submitLoungeReviewUseCase,
  })  : _getActiveSessionUseCase = getActiveSessionUseCase,
        _watchUserActiveSessionUseCase = watchUserActiveSessionUseCase,
        _streamActiveSessionUseCase = streamActiveSessionUseCase,
        _extendSessionTimeUseCase = extendSessionTimeUseCase,
        _requestSessionExtensionUseCase = requestSessionExtensionUseCase,
        _placeSessionOrderUseCase = placeSessionOrderUseCase,
        _getLoungeMenuUseCase = getLoungeMenuUseCase,
        _requestStaffAssistanceUseCase = requestStaffAssistanceUseCase,
        _submitLoungeReviewUseCase = submitLoungeReviewUseCase,
        super(const ActiveSessionState()) {
    _watchUserSessions();
  }

  void _watchUserSessions() {
    _userSessionsSubscription?.cancel();
    _userSessionsSubscription = subscribeWithRetry(
      streamFactory: () => _watchUserActiveSessionUseCase(),
      onData: (activeSession) {
        if (activeSession != null) {
          dev.log("[LIVESESSION_CUBIT] Watch Stream detected active session: ${activeSession.bookingId}");
          final currentSession = state.session;
          if (currentSession == null || currentSession.bookingId != activeSession.bookingId || state.status != ActiveSessionStatus.loaded) {
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

  bool _hasBeenReviewedOrPrompted(String bookingId) {
    final rawList = GetStorage().read<List>(CachingKey.REVIEWED_BOOKINGS) ?? [];
    return rawList.contains(bookingId);
  }

  void _markAsReviewedOrPrompted(String bookingId) {
    final rawList = GetStorage().read<List>(CachingKey.REVIEWED_BOOKINGS) ?? [];
    if (!rawList.contains(bookingId)) {
      rawList.add(bookingId);
      GetStorage().write(CachingKey.REVIEWED_BOOKINGS, rawList);
    }
  }

  void _showGlobalReviewBottomSheet(ActiveSession session) {
    if (_hasBeenReviewedOrPrompted(session.bookingId)) return;
    _markAsReviewedOrPrompted(session.bookingId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        AppBottomSheet.show(
          context: context,
          child: LoungeReviewBottomSheet(
            loungeName: session.loungeName.isNotEmpty ? session.loungeName : session.roomName,
            onSubmit: (rating, comment) {
              submitReview(rating: rating, comment: comment);
            },
          ),
        );
      }
    });
  }

  Future<void> loadActiveSession({String? bookingId}) async {
    dev.log("[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION: bookingId=$bookingId");
    if (isClosed) return;
    if (state.status != ActiveSessionStatus.loaded) {
      emit(state.copyWith(status: ActiveSessionStatus.loading));
    }

    final result = await _getActiveSessionUseCase(bookingId: bookingId);

    if (isClosed) return;

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
          final completed = state.session ?? state.completedSession;
          emit(state.copyWith(
            status: ActiveSessionStatus.empty,
            session: null,
            completedSession: completed,
          ));
          if (completed != null && state.session != null) {
            _showGlobalReviewBottomSheet(completed);
          }
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
      streamFactory: () => _streamActiveSessionUseCase(bookingId),
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
          final completed = state.session ?? updatedSession;
          emit(state.copyWith(
            status: ActiveSessionStatus.empty,
            session: null,
            completedSession: completed,
          ));
          if (status == BookingStatus.completed) {
            _showGlobalReviewBottomSheet(completed);
          }
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

  Future<void> loadMenu(String loungeId, {bool forceRefresh = false}) async {
    if (loungeId.isEmpty || isClosed) return;
    if (!forceRefresh && state.menu.isNotEmpty && state.session?.loungeId == loungeId) {
      return;
    }
    dev.log("[LIVESESSION_CUBIT] LOAD_MENU for lounge: $loungeId");
    final result = await _getLoungeMenuUseCase(loungeId: loungeId);
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

    final result = await _extendSessionTimeUseCase(
      bookingId: bookingId,
      additionalMinutes: additionalMinutes,
      additionalCost: cost,
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

  Future<void> requestExtension(int requestedMinutes) async {
    final active = state.session;
    if (active == null) return;

    HapticFeedback.mediumImpact();

    final bookingId = active.bookingId;
    dev.log("[LIVESESSION_CUBIT] REQUEST_EXTENSION: bookingId=$bookingId, minutes=$requestedMinutes");

    emit(state.copyWith(extendStatus: ActionStatus.loading));

    final result = await _requestSessionExtensionUseCase(
      bookingId: bookingId,
      requestedMinutes: requestedMinutes,
    );

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_EXTENSION FAILURE: ${failure.message}");
        emit(state.copyWith(
          extendStatus: ActionStatus.error,
          errorMessage: failure.message,
        ));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_EXTENSION SUCCESS");
        emit(state.copyWith(extendStatus: ActionStatus.success));
        loadActiveSession(bookingId: bookingId);
      },
    );
  }

  Future<void> requestStaffAssistance(String type, String? notes) async {
    final session = state.session;
    if (session == null) return;

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    dev.log("[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE: bookingId=$bookingId, type=$type");

    emit(state.copyWith(staffRequestStatus: ActionStatus.loading));

    final result = await _requestStaffAssistanceUseCase(
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

    final result = await _submitLoungeReviewUseCase(
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

  Future<void> placeOrder(List<OrderItem> items) async {
    final session = state.session;
    if (session == null) return;

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    dev.log("[LIVESESSION_CUBIT] PLACE_ORDER: bookingId=$bookingId, itemsCount=${items.length}");

    emit(state.copyWith(orderStatus: ActionStatus.loading));

    final result = await _placeSessionOrderUseCase(bookingId: bookingId, items: items);

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
