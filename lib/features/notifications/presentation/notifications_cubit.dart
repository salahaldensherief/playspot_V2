import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/router/app_router.dart';
import '../data/models/notification_model.dart';
import '../domain/repositories/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;
  StreamSubscription? _subscription;
  String? _lastLang;

  NotificationsCubit(this._repository) : super(NotificationsState());

  void getNotifications(String lang, {bool silent = false}) async {
    _lastLang = lang;
    if (!silent) {
      emit(state.copyWith(status: NotificationsStatus.loading));
    }
    
    final result = await _repository.getNotifications(lang);

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
        ));
        if (!silent) {
          _subscribeToNotifications();
        }
      },
    );
  }

  void _subscribeToNotifications() {
    _subscription?.cancel();
    _subscription = _repository.subscribeToNewNotifications().listen((record) {
      if (_lastLang != null) {
        final newNotification = NotificationModel.fromRawRecord(record, _lastLang!);
        
        // Add to list locally
        final updatedList = [newNotification, ...state.notifications];
        emit(state.copyWith(notifications: updatedList));

        // Show Toast if context is available
        final context = AppRouter.navigatorKey.currentContext;
        if (context != null) {
          GameHudToast.show(
            context,
            newNotification.body,
            type: ToastType.info,
          );
        }
      }
    });
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
