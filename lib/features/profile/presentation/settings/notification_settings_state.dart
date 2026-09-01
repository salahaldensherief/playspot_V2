import 'package:equatable/equatable.dart';

enum NotificationSettingsStatus { initial, loading, success, failure }

class NotificationSettingsState extends Equatable {
  final NotificationSettingsStatus status;
  final bool pushNotificationsEnabled;
  final bool bookingUpdates;
  final bool offersPromotions;
  final bool systemStatus;
  final bool tournamentsAndEvents;
  final String? errorMessage;

  const NotificationSettingsState({
    this.status = NotificationSettingsStatus.initial,
    this.pushNotificationsEnabled = true,
    this.bookingUpdates = true,
    this.offersPromotions = true,
    this.systemStatus = true,
    this.tournamentsAndEvents = true,
    this.errorMessage,
  });

  NotificationSettingsState copyWith({
    NotificationSettingsStatus? status,
    bool? pushNotificationsEnabled,
    bool? bookingUpdates,
    bool? offersPromotions,
    bool? systemStatus,
    bool? tournamentsAndEvents,
    String? errorMessage,
  }) {
    return NotificationSettingsState(
      status: status ?? this.status,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      offersPromotions: offersPromotions ?? this.offersPromotions,
      systemStatus: systemStatus ?? this.systemStatus,
      tournamentsAndEvents: tournamentsAndEvents ?? this.tournamentsAndEvents,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        pushNotificationsEnabled,
        bookingUpdates,
        offersPromotions,
        systemStatus,
        tournamentsAndEvents,
        errorMessage,
      ];
}
