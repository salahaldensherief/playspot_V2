import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/cache/preference_manager.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../data/models/notification_settings_model.dart';
import '../../domain/repositories/profile_repository.dart';
import 'notification_settings_state.dart';

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  final ProfileRepository _profileRepository;
  final PreferenceManager _pref;

  NotificationSettingsCubit(this._profileRepository, this._pref)
      : super(const NotificationSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    emit(state.copyWith(
      pushNotificationsEnabled: _pref.pushEnabled(),
      bookingUpdates: _pref.bookingUpdatesEnabled(),
      offersPromotions: _pref.offersEnabled(),
      systemStatus: _pref.systemNotifEnabled(),
      tournamentsAndEvents: _pref.tournamentsEnabled(),
    ));

    final result = await _profileRepository.getNotificationSettings();
    result.fold(
      (_) {},
      (model) {
        if (!isClosed) {
          _pref.savePushEnabled(model.pushEnabled);
          _pref.saveBookingUpdatesEnabled(model.bookingUpdates);
          _pref.saveOffersEnabled(model.offersEnabled);
          _pref.saveTournamentsEnabled(model.eventsEnabled);
          _pref.saveSystemNotifEnabled(model.systemNotifications);

          final newState = state.copyWith(
            pushNotificationsEnabled: model.pushEnabled,
            bookingUpdates: model.bookingUpdates,
            offersPromotions: model.offersEnabled,
            tournamentsAndEvents: model.eventsEnabled,
            systemStatus: model.systemNotifications,
          );

          emit(newState);

          if (model.pushEnabled) {
            _syncAllToFirebase(newState);
          } else {
            _unsubscribeFromAll();
          }
        }
      },
    );
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

    if (!isClosed) {
      emit(newState);
    }
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
    final model = NotificationSettingsModel(
      pushEnabled: s.pushNotificationsEnabled,
      bookingUpdates: s.bookingUpdates,
      offersEnabled: s.offersPromotions,
      eventsEnabled: s.tournamentsAndEvents,
      systemNotifications: s.systemStatus,
    );
    await _profileRepository.updateNotificationSettings(model);
    await _profileRepository.updateNotificationPreferences({
      'push_enabled': s.pushNotificationsEnabled,
      'booking_updates': s.bookingUpdates,
      'offers_promotions': s.offersPromotions,
      'system_status': s.systemStatus,
      'tournaments_events': s.tournamentsAndEvents,
    });
  }
}
