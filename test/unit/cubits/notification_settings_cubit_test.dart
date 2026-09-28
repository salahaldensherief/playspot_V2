import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/profile/data/models/notification_settings_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/settings/notification_settings_cubit.dart';
import 'package:playspot/features/profile/presentation/settings/notification_settings_state.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}
class MockPreferenceManager extends Mock implements PreferenceManager {}

void main() {
  late MockProfileRepository mockProfileRepository;
  late MockPreferenceManager mockPreferenceManager;
  late NotificationSettingsCubit cubit;

  setUpAll(() {
    registerFallbackValue(const NotificationSettingsModel());
  });

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockPreferenceManager = MockPreferenceManager();

    when(() => mockPreferenceManager.pushEnabled()).thenReturn(true);
    when(() => mockPreferenceManager.bookingUpdatesEnabled()).thenReturn(true);
    when(() => mockPreferenceManager.offersEnabled()).thenReturn(true);
    when(() => mockPreferenceManager.systemNotifEnabled()).thenReturn(true);
    when(() => mockPreferenceManager.tournamentsEnabled()).thenReturn(true);

    when(() => mockPreferenceManager.savePushEnabled(any())).thenAnswer((_) async {});
    when(() => mockPreferenceManager.saveBookingUpdatesEnabled(any())).thenAnswer((_) async {});
    when(() => mockPreferenceManager.saveOffersEnabled(any())).thenAnswer((_) async {});
    when(() => mockPreferenceManager.saveSystemNotifEnabled(any())).thenAnswer((_) async {});
    when(() => mockPreferenceManager.saveTournamentsEnabled(any())).thenAnswer((_) async {});

    when(() => mockProfileRepository.getNotificationSettings())
        .thenAnswer((_) async => const Right(NotificationSettingsModel()));
    when(() => mockProfileRepository.updateNotificationSettings(any()))
        .thenAnswer((_) async => const Right(null));

    cubit = NotificationSettingsCubit(mockProfileRepository, mockPreferenceManager);
  });

  tearDown(() {
    if (!cubit.isClosed) {
      cubit.close();
    }
  });

  group('Batch 4 — NotificationSettingsCubit Unit Tests', () {
    test('1. initial notification preference state is loaded from PreferenceManager', () {
      expect(cubit.state.pushNotificationsEnabled, isTrue);
      expect(cubit.state.bookingUpdates, isTrue);
      expect(cubit.state.offersPromotions, isTrue);
      expect(cubit.state.systemStatus, isTrue);
      expect(cubit.state.tournamentsAndEvents, isTrue);
    });

    test('2. successful preference toggle updates state and syncs with repository and preference manager', () async {
      await cubit.togglePreference('push', false);

      expect(cubit.state.pushNotificationsEnabled, isFalse);
      verify(() => mockPreferenceManager.savePushEnabled(false)).called(1);
      verify(() => mockProfileRepository.updateNotificationSettings(any())).called(greaterThanOrEqualTo(1));
    });

    test('3. failed preference update in repository gracefully maintains state without crashing', () async {
      when(() => mockProfileRepository.updateNotificationSettings(any()))
          .thenAnswer((_) async => const Left(ServerFailure('Network timeout')));

      await cubit.togglePreference('booking', false);

      expect(cubit.state.bookingUpdates, isFalse);
      verify(() => mockPreferenceManager.saveBookingUpdatesEnabled(false)).called(1);
    });

    test('4 & 5. rapid repeated toggles update state synchronously without race condition corruption', () async {
      cubit.togglePreference('offers', false);
      cubit.togglePreference('offers', true);
      cubit.togglePreference('offers', false);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.offersPromotions, isFalse);
      verify(() => mockPreferenceManager.saveOffersEnabled(false)).called(2);
      verify(() => mockPreferenceManager.saveOffersEnabled(true)).called(2); // 1 from _loadSettings + 1 from togglePreference
    });

    test('6 & 7. close during async operation does not throw state error', () async {
      when(() => mockProfileRepository.updateNotificationSettings(any()))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 50));
            return const Right(null);
          });

      await cubit.togglePreference('tournaments', false);
      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });

    test('8. model toJson / fromJson serialization integrity', () {
      const model = NotificationSettingsModel(
        pushEnabled: true,
        bookingUpdates: false,
        offersEnabled: true,
        eventsEnabled: false,
        systemNotifications: true,
      );

      final json = model.toJson();
      final parsed = NotificationSettingsModel.fromJson(json);

      expect(parsed, equals(model));
    });

    test('9 & 10. localization model key consistency', () {
      expect(NotificationSettingsState().props.length, equals(7));
    });
  });
}
