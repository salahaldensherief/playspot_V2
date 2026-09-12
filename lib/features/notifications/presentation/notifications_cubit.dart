import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';
import 'package:playspot/features/notifications/domain/repositories/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  static const int _pageSize = 20;
  final NotificationsRepository _repository;
  StreamSubscription? _subscription;
  String? _lastLang;

  // Set to track processed active session IDs so navigation triggers only once per session
  final Set<String> _processedActiveSessionIds = {};

  NotificationsCubit(this._repository) : super(const NotificationsState());

  void getNotifications(String lang, {bool silent = false}) {
    loadNotifications(lang, silent: silent);
  }

  Future<void> loadNotifications(String lang, {bool silent = false}) async {
    _lastLang = lang;
    if (!silent && !isClosed) {
      emit(state.copyWith(
        status: NotificationsStatus.loading,
        page: 1,
        hasMore: true,
      ));
    }

    final result = await _repository.getNotifications(
      lang,
      page: 1,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed && !silent) {
          emit(state.copyWith(
            status: NotificationsStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (PaginatedResponse<NotificationModel> paginatedRes) {
        if (!isClosed) {
          emit(state.copyWith(
            status: NotificationsStatus.success,
            notifications: paginatedRes.items,
            page: paginatedRes.page,
            totalCount: paginatedRes.totalCount,
            hasMore: paginatedRes.hasMore,
            isLoadingMore: false,
          ));
          if (!silent && !isClosed) {
            _subscribeToNotifications();
          }
        }
      },
    );
  }

  Future<void> loadMoreNotifications(String lang) async {
    if (!state.hasMore || state.isLoadingMore || state.status == NotificationsStatus.loading) {
      return;
    }

    _lastLang = lang;
    final nextPage = state.page + 1;
    if (!isClosed) {
      emit(state.copyWith(isLoadingMore: true));
    }

    final result = await _repository.getNotifications(
      lang,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            isLoadingMore: false,
            errorMessage: failure.message,
          ));
        }
      },
      (PaginatedResponse<NotificationModel> paginatedRes) {
        if (!isClosed) {
          final updatedList = List<NotificationModel>.from(state.notifications)
            ..addAll(paginatedRes.items);

          emit(state.copyWith(
            notifications: updatedList,
            page: paginatedRes.page,
            totalCount: paginatedRes.totalCount,
            hasMore: paginatedRes.hasMore,
            isLoadingMore: false,
          ));
        }
      },
    );
  }

  Future<void> refreshNotifications(String lang) async {
    await loadNotifications(lang, silent: true);
  }

  void _subscribeToNotifications() {
    _subscription?.cancel();
    _subscription = _repository.subscribeToNewNotifications().listen((record) {
      if (isClosed) return;
      if (_lastLang != null) {
        final newNotification = NotificationModel.fromRawRecord(record, _lastLang!);

        // Add to list locally
        final updatedList = [newNotification, ...state.notifications];
        if (!isClosed) {
          emit(state.copyWith(
            notifications: updatedList,
            totalCount: state.totalCount + 1,
          ));
        }

        // Show Toast safely
        GameHudToast.show(
          null,
          newNotification.getBody(_lastLang!),
          type: ToastType.info,
        );

        // Automated Active Session Navigation Trigger
        _checkAndTriggerActiveSessionNavigation(record, newNotification);
      }
    });
  }

  void _checkAndTriggerActiveSessionNavigation(
    Map<String, dynamic> record,
    NotificationModel notification,
  ) {
    final typeStr = (record['type'] ?? notification.type.name)
        .toString()
        .toLowerCase();
    final isRead = (record['is_read'] as bool?) ?? notification.isRead;

    if (typeStr.contains('active_session') && !isRead) {
      final data = notification.data ?? {};
      final bookingId = _extractBookingId(data, record, notification);
      final sessionKey = bookingId.isNotEmpty ? bookingId : notification.id;

      if (!_processedActiveSessionIds.contains(sessionKey)) {
        _processedActiveSessionIds.add(sessionKey);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = AppRouter.navigatorKey.currentContext;
          if (context != null) {
            context.pushNamed(RouterKeys.activeSession);
          }
        });
      }
    }
  }

  String _extractBookingId(
    Map<String, dynamic> data,
    Map<String, dynamic> record,
    NotificationModel notification,
  ) {
    final possibleKeys = [
      'booking_id',
      'bookingId',
      'id',
      'target_id',
      'reference_id',
    ];
    for (final key in possibleKeys) {
      final val = data[key]?.toString() ?? record[key]?.toString();
      if (val != null && val.trim().isNotEmpty && val != 'null') {
        return val.trim();
      }
    }
    return '';
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void markAsRead(String id) async {
    if (isClosed) return;
    final updatedList = state.notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();

    emit(state.copyWith(notifications: updatedList));

    final result = await _repository.markAsRead(id);

    if (isClosed) return;

    result.fold(
      (failure) {
        // Keep optimism, state remains marked as read locally
        if (!isClosed) emit(state.copyWith(notifications: updatedList));
      },
      (_) {
        if (!isClosed) emit(state.copyWith(notifications: updatedList));
      },
    );
  }

  void markAllAsRead() async {
    if (isClosed) return;
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();

    emit(state.copyWith(notifications: updatedList));

    final result = await _repository.markAllAsRead();

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed) emit(state.copyWith(notifications: updatedList));
      },
      (_) {
        if (!isClosed) emit(state.copyWith(notifications: updatedList));
      },
    );
  }
}
