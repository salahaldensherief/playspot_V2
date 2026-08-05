import '../cubit/notifications_cubit.dart';
import '../../data/models/notification_model.dart';

enum NotificationsStatus { initial, loading, success, error }

class NotificationsState {
  final List<NotificationModel> notifications;
  final NotificationsStatus status;
  final String? errorMessage;

  NotificationsState({
    this.notifications = const [],
    this.status = NotificationsStatus.initial,
    this.errorMessage,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    NotificationsStatus? status,
    String? errorMessage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}
