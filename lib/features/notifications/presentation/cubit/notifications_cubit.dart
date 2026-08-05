import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/repos/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;
  NotificationsCubit(this._repository) : super(NotificationsState());

  void getNotifications(String lang) async {
    emit(state.copyWith(status: NotificationsStatus.loading));
    
    final result = await _repository.getNotifications(lang);

    result.fold(
      (failure) => emit(state.copyWith(
        status: NotificationsStatus.error,
        errorMessage: failure.message,
      )),
      (notifications) => emit(state.copyWith(
        status: NotificationsStatus.success,
        notifications: notifications,
      )),
    );
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
      (_) => null,
    );
  }

  void markAllAsRead() async {
    final originalList = List.of(state.notifications);
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    
    emit(state.copyWith(notifications: updatedList));

    final result = await _repository.markAllAsRead();
    
    result.fold(
      (failure) => emit(state.copyWith(notifications: originalList)),
      (_) => null,
    );
  }
}
