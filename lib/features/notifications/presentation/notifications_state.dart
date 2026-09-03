import 'package:equatable/equatable.dart';
import '../data/models/notification_model.dart';

enum NotificationsStatus { initial, loading, success, error }

class NotificationsState extends Equatable {
  final List<NotificationModel> notifications;
  final NotificationsStatus status;
  final String? errorMessage;
  final bool hasMore;
  final bool isLoadingMore;
  final int offset;

  const NotificationsState({
    this.notifications = const [],
    this.status = NotificationsStatus.initial,
    this.errorMessage,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.offset = 0,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    NotificationsStatus? status,
    String? errorMessage,
    bool? hasMore,
    bool? isLoadingMore,
    int? offset,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      offset: offset ?? this.offset,
    );
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [
        notifications,
        status,
        errorMessage,
        hasMore,
        isLoadingMore,
        offset,
      ];
}

