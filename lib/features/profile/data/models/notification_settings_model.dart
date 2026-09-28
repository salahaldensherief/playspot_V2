import 'package:equatable/equatable.dart';

class NotificationSettingsModel extends Equatable {
  final bool pushEnabled;
  final bool bookingUpdates;
  final bool offersEnabled;
  final bool eventsEnabled;
  final bool systemNotifications;

  const NotificationSettingsModel({
    this.pushEnabled = true,
    this.bookingUpdates = true,
    this.offersEnabled = true,
    this.eventsEnabled = true,
    this.systemNotifications = true,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      bookingUpdates: json['booking_updates'] as bool? ?? true,
      offersEnabled: json['offers_enabled'] as bool? ?? true,
      eventsEnabled: json['events_enabled'] as bool? ?? true,
      systemNotifications: json['system_notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'booking_updates': bookingUpdates,
      'offers_enabled': offersEnabled,
      'events_enabled': eventsEnabled,
      'system_notifications': systemNotifications,
    };
  }

  NotificationSettingsModel copyWith({
    bool? pushEnabled,
    bool? bookingUpdates,
    bool? offersEnabled,
    bool? eventsEnabled,
    bool? systemNotifications,
  }) {
    return NotificationSettingsModel(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      offersEnabled: offersEnabled ?? this.offersEnabled,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      systemNotifications: systemNotifications ?? this.systemNotifications,
    );
  }

  @override
  List<Object?> get props => [
        pushEnabled,
        bookingUpdates,
        offersEnabled,
        eventsEnabled,
        systemNotifications,
      ];
}
