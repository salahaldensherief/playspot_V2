import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
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
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));

      final expectedStates = [
        const NotificationsState(
          status: NotificationsStatus.loading,
          page: 1,
          hasMore: true,
        ),
        NotificationsState(
          status: NotificationsStatus.success,
          notifications: [testNotification],
          page: 1,
          totalCount: 1,
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
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => const Left(ServerFailure('Failed to load')));

      final expectedStates = [
        const NotificationsState(
          status: NotificationsStatus.loading,
          page: 1,
          hasMore: true,
        ),
        const NotificationsState(
          status: NotificationsStatus.error,
          errorMessage: 'Failed to load',
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadNotifications('en');
    });

    test('markAsRead performs optimistic update', () async {
      when(() => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAsRead('notif_1'))
          .thenAnswer((_) async => const Right(null));

      cubit.markAsRead('notif_1');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isTrue);
      verify(() => mockRepository.markAsRead('notif_1')).called(1);
    });

    test('markAsRead duplicate / race condition calls repository ONLY once', () async {
      when(() => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAsRead('notif_1'))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return const Right(null);
          });

      // Simultaneous dual invocation
      cubit.markAsRead('notif_1');
      cubit.markAsRead('notif_1');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(cubit.state.notifications.first.isRead, isTrue);
      verify(() => mockRepository.markAsRead('notif_1')).called(1);
    });

    test('markAsRead failure rolls back optimistic update to unread', () async {
      when(() => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAsRead('notif_1'))
          .thenAnswer((_) async => const Left(ServerFailure('Database update failed')));

      cubit.markAsRead('notif_1');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isFalse);
      expect(cubit.state.errorMessage, equals('Database update failed'));
    });

    test('markAllAsRead duplicate / race condition calls repository ONLY once', () async {
      when(() => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAllAsRead())
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return const Right(null);
          });

      // Simultaneous dual invocation
      cubit.markAllAsRead();
      cubit.markAllAsRead();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(cubit.state.notifications.every((n) => n.isRead), isTrue);
      verify(() => mockRepository.markAllAsRead()).called(1);
    });

    test('markAllAsRead failure rolls back optimistic update', () async {
      when(() => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => Right(PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          )));
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAllAsRead())
          .thenAnswer((_) async => const Left(ServerFailure('Bulk update failed')));

      cubit.markAllAsRead();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isFalse);
      expect(cubit.state.errorMessage, equals('Bulk update failed'));
    });
  });
}


