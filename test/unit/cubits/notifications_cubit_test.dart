import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';
import 'package:playspot/features/notifications/presentation/notifications_cubit.dart';
import 'package:playspot/features/notifications/presentation/notifications_state.dart';

class MockNotificationsRepository extends Mock implements NotificationsRepository {}

void main() {
  late MockNotificationsRepository mockRepository;
  late NotificationsCubit cubit;

  final testNotification = NotificationModel(
    id: 'notif_1',
    title: 'Booking Confirmed',
    body: 'Your booking has been accepted',
    createdAt: DateTime.now(),
    isRead: false,
    type: NotificationType.booking,
  );

  setUp(() {
    mockRepository = MockNotificationsRepository();
    when(() => mockRepository.subscribeToNewNotifications())
        .thenAnswer((_) => const Stream.empty());

    cubit = NotificationsCubit(mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('NotificationsCubit Unit Tests', () {
    test('initial state is correct', () {
      expect(cubit.state.status, NotificationsStatus.initial);
      expect(cubit.state.notifications, isEmpty);
      expect(cubit.state.hasMore, isTrue);
    });

    test('loadNotifications emits [loading, success] on success', () async {
      when(() => mockRepository.getNotifications(
            'en',
            limit: any(named: 'limit'),
            offset: 0,
          )).thenAnswer((_) async => Right([testNotification]));

      final expectedStates = [
        const NotificationsState(status: NotificationsStatus.loading),
        NotificationsState(
          status: NotificationsStatus.success,
          notifications: [testNotification],
          offset: 1,
          hasMore: false,
          isLoadingMore: false,
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadNotifications('en');
    });

    test('loadNotifications emits [loading, error] on failure', () async {
      when(() => mockRepository.getNotifications(
            'en',
            limit: any(named: 'limit'),
            offset: 0,
          )).thenAnswer((_) async => const Left(ServerFailure('Failed to load')));

      final expectedStates = [
        const NotificationsState(status: NotificationsStatus.loading),
        const NotificationsState(
          status: NotificationsStatus.error,
          errorMessage: 'Failed to load',
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadNotifications('en');
    });

    test('markAsRead performs optimistic update and rolls back on failure', () async {
      when(() => mockRepository.getNotifications('en', limit: any(named: 'limit'), offset: 0))
          .thenAnswer((_) async => Right([testNotification]));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAsRead('notif_1'))
          .thenAnswer((_) async => const Left(ServerFailure('Failed')));

      cubit.markAsRead('notif_1');

      // Check that failure reverted back to original unread state
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isFalse);
    });
  });
}
