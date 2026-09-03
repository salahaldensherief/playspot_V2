import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../data/models/notification_model.dart';
import '../domain/repositories/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  static const int _pageSize = 15;
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
    if (!silent) {
      emit(state.copyWith(
        status: NotificationsStatus.loading,
        offset: 0,
        hasMore: true,
      ));
    }

    final result = await _repository.getNotifications(
      lang,
      limit: _pageSize,
      offset: 0,
    );

    result.fold(
      (failure) {
        if (!silent) {
          emit(state.copyWith(
            status: NotificationsStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (notifications) {
        emit(state.copyWith(
          status: NotificationsStatus.success,
          notifications: notifications,
          offset: notifications.length,
          hasMore: notifications.length >= _pageSize,
          isLoadingMore: false,
        ));
        if (!silent) {
          _subscribeToNotifications();
        }
      },
    );
  }

  Future<void> loadMoreNotifications(String lang) async {
    if (!state.hasMore || state.isLoadingMore || state.status == NotificationsStatus.loading) {
      return;
    }

    _lastLang = lang;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _repository.getNotifications(
      lang,
      limit: _pageSize,
      offset: state.offset,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isLoadingMore: false,
          errorMessage: failure.message,
        ));
      },
      (newNotifications) {
        final updatedList = List<NotificationModel>.from(state.notifications)
          ..addAll(newNotifications);

        emit(state.copyWith(
          notifications: updatedList,
          offset: state.offset + newNotifications.length,
          hasMore: newNotifications.length >= _pageSize,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> refreshNotifications(String lang) async {
    await loadNotifications(lang, silent: true);
  }

  void _subscribeToNotifications() {
    _subscription?.cancel();
    _subscription = _repository.subscribeToNewNotifications().listen((record) {
      if (_lastLang != null) {
        final newNotification = NotificationModel.fromRawRecord(record, _lastLang!);
        
        // Add to list locally
        final updatedList = [newNotification, ...state.notifications];
        emit(state.copyWith(notifications: updatedList));

        // Show Toast safely
        GameHudToast.show(
          null,
          newNotification.body,
          type: ToastType.info,
        );

        // 🚀 Automated Active Session Navigation Trigger
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
    final originalList = List.of(state.notifications);
    final updatedList = state.notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    
    emit(state.copyWith(notifications: updatedList));

    final result = await _repository.markAsRead(id);
    
    result.fold(
      (failure) => emit(state.copyWith(notifications: originalList)),
      (_) => emit(state.copyWith(notifications: updatedList)),
    );
  }

  void markAllAsRead() async {
    final originalList = List.of(state.notifications);
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    
    emit(state.copyWith(notifications: updatedList));

    final result = await _repository.markAllAsRead();
    
    result.fold(
      (failure) => emit(state.copyWith(notifications: originalList)),
      (_) => emit(state.copyWith(notifications: updatedList)),
    );
  }
}
