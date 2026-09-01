import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/cache/preference_manager.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../domain/repositories/profile_repository.dart';
import 'notification_settings_state.dart';

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  final ProfileRepository _profileRepository;
  final PreferenceManager _pref;

  NotificationSettingsCubit(this._profileRepository, this._pref) : super(const NotificationSettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    emit(state.copyWith(
      pushNotificationsEnabled: _pref.pushEnabled(),
      bookingUpdates: _pref.bookingUpdatesEnabled(),
      offersPromotions: _pref.offersEnabled(),
      systemStatus: _pref.systemNotifEnabled(),
      tournamentsAndEvents: _pref.tournamentsEnabled(),
    ));
  }

  Future<void> togglePreference(String key, bool value) async {
    NotificationSettingsState newState = state;

    switch (key) {
      case 'push':
        newState = state.copyWith(pushNotificationsEnabled: value);
        _pref.savePushEnabled(value);
        if (value) {
          _syncAllToFirebase(newState);
        } else {
          _unsubscribeFromAll();
        }
        break;
      case 'booking':
        newState = state.copyWith(bookingUpdates: value);
        _pref.saveBookingUpdatesEnabled(value);
        _toggleTopic('user_bookings', value);
        break;
      case 'offers':
        newState = state.copyWith(offersPromotions: value);
        _pref.saveOffersEnabled(value);
        _toggleTopic('offers_and_promos', value);
        break;
      case 'system':
        newState = state.copyWith(systemStatus: value);
        _pref.saveSystemNotifEnabled(value);
        _toggleTopic('system_announcements', value);
        break;
      case 'tournaments':
        newState = state.copyWith(tournamentsAndEvents: value);
        _pref.saveTournamentsEnabled(value);
        _toggleTopic('tournaments_and_events', value);
        break;
    }

    emit(newState);
    _syncToSupabase(newState);
  }

  void _toggleTopic(String topic, bool enable) {
    if (state.pushNotificationsEnabled) {
      PushNotificationService.instance.toggleTopicSubscription(topic: topic, enable: enable);
    }
  }

  void _syncAllToFirebase(NotificationSettingsState s) {
    PushNotificationService.instance.syncAllTopicsFromPreferences({
      'user_bookings': s.bookingUpdates,
      'offers_and_promos': s.offersPromotions,
      'system_announcements': s.systemStatus,
      'tournaments_and_events': s.tournamentsAndEvents,
    });
  }

  void _unsubscribeFromAll() {
     PushNotificationService.instance.syncAllTopicsFromPreferences({
      'user_bookings': false,
      'offers_and_promos': false,
      'system_announcements': false,
      'tournaments_and_events': false,
    });
  }

  Future<void> _syncToSupabase(NotificationSettingsState s) async {
    await _profileRepository.updateNotificationPreferences({
      'push_enabled': s.pushNotificationsEnabled,
      'booking_updates': s.bookingUpdates,
      'offers_promotions': s.offersPromotions,
      'system_status': s.systemStatus,
      'tournaments_events': s.tournamentsAndEvents,
    });
  }
}
