import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/services/play_spot_live_activity_service.dart';
import 'package:playspot/core/mixins/realtime_watcher_mixin.dart';
import '../../../../core/constants/booking_status.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/native_notification_service.dart';
import '../domain/entities/active_session.dart';
import '../domain/entities/order_item.dart';
import '../domain/entities/out_of_stock_item.dart';
import '../domain/entities/upsell_suggestion.dart';
import '../domain/usecases/extend_session_time_usecase.dart';
import '../domain/usecases/get_active_session_usecase.dart';
import '../domain/usecases/get_canteen_menu_usecase.dart';
import '../domain/usecases/get_lounge_menu_usecase.dart';
import '../domain/usecases/get_upsell_suggestions_usecase.dart';
import '../domain/usecases/place_session_order_usecase.dart';
import '../domain/usecases/record_upsell_event_usecase.dart';
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

part 'active_session_stream.dart';
part 'active_session_menu.dart';
part 'active_session_upsell.dart';
part 'active_session_extension.dart';
part 'active_session_review.dart';
part 'active_session_order.dart';

class ActiveSessionCubit extends Cubit<ActiveSessionState>
    with RealtimeWatcherMixin {
  final GetActiveSessionUseCase _getActiveSessionUseCase;
  final WatchUserActiveSessionUseCase _watchUserActiveSessionUseCase;
  final StreamActiveSessionUseCase _streamActiveSessionUseCase;
  final RequestSessionExtensionUseCase _requestSessionExtensionUseCase;
  final PlaceSessionOrderUseCase _placeSessionOrderUseCase;
  final GetCanteenMenuUseCase _getCanteenMenuUseCase;
  final GetUpsellSuggestionsUseCase _getUpsellSuggestionsUseCase;
  final RecordUpsellEventUseCase _recordUpsellEventUseCase;
  final RequestStaffAssistanceUseCase _requestStaffAssistanceUseCase;
  final SubmitLoungeReviewUseCase _submitLoungeReviewUseCase;

  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _userSessionsSubscription;
  String? _subscribedBookingId;
  int _sessionLoadVersion = 0;
  int _menuLoadVersion = 0;
  String? _loadedMenuLoungeId;
  int _upsellLoadVersion = 0;
  int _sessionEpoch = 0;
  String? _pendingBookingId;
  String? _requestedMenuLoungeId;

  ActiveSessionCubit({
    required GetActiveSessionUseCase getActiveSessionUseCase,
    required WatchUserActiveSessionUseCase watchUserActiveSessionUseCase,
    required StreamActiveSessionUseCase streamActiveSessionUseCase,
    ExtendSessionTimeUseCase? extendSessionTimeUseCase,
    required RequestSessionExtensionUseCase requestSessionExtensionUseCase,
    required PlaceSessionOrderUseCase placeSessionOrderUseCase,
    GetLoungeMenuUseCase? getLoungeMenuUseCase,
    required GetCanteenMenuUseCase getCanteenMenuUseCase,
    required GetUpsellSuggestionsUseCase getUpsellSuggestionsUseCase,
    required RecordUpsellEventUseCase recordUpsellEventUseCase,
    required RequestStaffAssistanceUseCase requestStaffAssistanceUseCase,
    required SubmitLoungeReviewUseCase submitLoungeReviewUseCase,
  }) : _getActiveSessionUseCase = getActiveSessionUseCase,
       _watchUserActiveSessionUseCase = watchUserActiveSessionUseCase,
       _streamActiveSessionUseCase = streamActiveSessionUseCase,
       _requestSessionExtensionUseCase = requestSessionExtensionUseCase,
       _placeSessionOrderUseCase = placeSessionOrderUseCase,
       _getCanteenMenuUseCase = getCanteenMenuUseCase,
       _getUpsellSuggestionsUseCase = getUpsellSuggestionsUseCase,
       _recordUpsellEventUseCase = recordUpsellEventUseCase,
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
        if (isClosed) return;
        if (activeSession == null) {
          _clearSession();
          return;
        }
        if (activeSession != null) {
          dev.log(
            "[LIVESESSION_CUBIT] Watch Stream detected active session: ${activeSession.bookingId}",
          );
          final currentSession = state.session;
          if (currentSession == null ||
              currentSession.bookingId != activeSession.bookingId ||
              state.status != ActiveSessionStatus.loaded) {
            if (_pendingBookingId == activeSession.bookingId) return;
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
            loungeName: session.loungeName.isNotEmpty
                ? session.loungeName
                : session.roomName,
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
    final loadVersion = ++_sessionLoadVersion;
    if (bookingId != null && bookingId != state.session?.bookingId) {
      _resetSessionScope();
      emit(const ActiveSessionState(status: ActiveSessionStatus.loading));
    }
    _pendingBookingId = bookingId;
    if (state.status != ActiveSessionStatus.loaded) {
      emit(state.copyWith(status: ActiveSessionStatus.loading));
    }

    final result = await _getActiveSessionUseCase(bookingId: bookingId);

    if (isClosed || loadVersion != _sessionLoadVersion) return;
    _pendingBookingId = null;

    result.fold(
      (failure) {
        dev.log(
          "[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION FAILURE: ${failure.message}",
        );
        emit(
          state.copyWith(
            status: ActiveSessionStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (session) {
        if (session == null) {
          dev.log(
            "[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION EMPTY: No session found",
          );
          _clearSession();
          LocalNotificationService.instance.cancelActiveSessionNotification();
          NativeNotificationService.instance.cancelCustomNotification();
          PlaySpotLiveActivityService.instance.endActivity();
        } else {
          if (state.session?.bookingId != session.bookingId) {
            _resetSessionScope();
          }
          dev.log(
            "[LIVESESSION_CUBIT] LOAD_ACTIVE_SESSION LOADED: bookingId=${session.bookingId}, status=${session.status}",
          );
          emit(
            (state.session?.bookingId == session.bookingId
                    ? state
                    : const ActiveSessionState())
                .copyWith(status: ActiveSessionStatus.loaded, session: session),
          );
          _subscribeToRealtime(session.bookingId);
          loadMenu(session.loungeId);
          loadUpsellSuggestions(session.bookingId);

          try {
            PlaySpotLiveActivityService.instance.startActivity(
              sessionId: session.bookingId,
              hallName: session.loungeName.isNotEmpty
                  ? session.loungeName
                  : 'PlaySpot Lounge',
              deviceName: session.deviceName.isNotEmpty
                  ? session.deviceName
                  : session.roomName,
              endTimeTimestamp: session.endTime.millisecondsSinceEpoch ~/ 1000,
            );

            final notificationId =
                session.bookingId.hashCode.abs() & 0x7FFFFFFF;
            LocalNotificationService.instance.scheduleSessionExpiryWarning(
              id: notificationId,
              loungeName: session.loungeName.isNotEmpty
                  ? session.loungeName
                  : 'Lounge',
              expiryTime: session.endTime,
            );
          } catch (_) {}
        }
      },
    );
  }

  void clearUnavailableItems() {
    emit(state.copyWith(unavailableItems: []));
  }

  void _publish(ActiveSessionState next) => emit(next);
  Future<void> loadMenu(String loungeId, {bool forceRefresh = false}) =>
      _loadMenuImpl(loungeId, forceRefresh: forceRefresh);
  Future<void> loadUpsellSuggestions(String bookingId) =>
      _loadUpsellSuggestionsImpl(bookingId);
  Future<void> recordUpsellImpression(UpsellSuggestion suggestion) =>
      _recordUpsellImpressionImpl(suggestion);
  Future<void> dismissUpsellSuggestion(UpsellSuggestion suggestion) =>
      _dismissUpsellSuggestionImpl(suggestion);
  Future<void> acceptUpsellSuggestion(
    UpsellSuggestion suggestion, {
    String? orderId,
    double? amount,
  }) =>
      _acceptUpsellSuggestionImpl(suggestion, orderId: orderId, amount: amount);
  Future<void> extendTime(int additionalMinutes, [double? precalculatedCost]) =>
      requestExtension(additionalMinutes);
  Future<void> requestExtension(int requestedMinutes) =>
      _requestExtensionImpl(requestedMinutes);
  Future<void> requestStaffAssistance(String type, String? notes) =>
      _requestStaffAssistanceImpl(type, notes);
  Future<void> submitReview({required double rating, String? comment}) =>
      _submitReviewImpl(rating: rating, comment: comment);
  Future<void> placeOrder(List<OrderItem> items) => _placeOrderImpl(items);

  @override
  Future<void> close() async {
    ++_sessionLoadVersion;
    _resetSessionScope();
    await _userSessionsSubscription?.cancel();
    await super.close();
  }

  void _resetSessionScope() {
    ++_sessionEpoch;
    ++_menuLoadVersion;
    ++_upsellLoadVersion;
    _requestedMenuLoungeId = null;
    _loadedMenuLoungeId = null;
    _pendingBookingId = null;
    _subscribedBookingId = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  void _clearSession({ActiveSession? completed}) {
    ++_sessionLoadVersion;
    _resetSessionScope();
    emit(
      ActiveSessionState(
        status: ActiveSessionStatus.empty,
        completedSession: completed,
      ),
    );
  }
}
