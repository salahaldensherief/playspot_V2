import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';
import 'package:playspot/features/notifications/presentation/notifications_cubit.dart';
import 'package:playspot/features/notifications/presentation/notifications_state.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

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
    when(
      () => mockRepository.subscribeToNewNotifications(),
    ).thenAnswer((_) => const Stream.empty());

    cubit = NotificationsCubit(mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('NotificationsCubit Unit Tests', () {
    test('reloads keep a single realtime subscription', () async {
      when(
        () => mockRepository.getNotifications(any(), page: 1, pageSize: 20),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          ),
        ),
      );
      await cubit.loadNotifications('en');
      await cubit.loadNotifications('ar');
      verify(() => mockRepository.subscribeToNewNotifications()).called(1);
    });

    test(
      'close awaits cancellation and ignores responses during disposal',
      () async {
        final cancellation = Completer<void>();
        final stream = StreamController<Map<String, dynamic>>(
          onCancel: () => cancellation.future,
        );
        when(
          () => mockRepository.subscribeToNewNotifications(),
        ).thenAnswer((_) => stream.stream);
        when(
          () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
        ).thenAnswer(
          (_) async => Right(
            PaginatedResponse<NotificationModel>(
              items: [testNotification],
              totalCount: 1,
              page: 1,
              pageSize: 20,
            ),
          ),
        );
        await cubit.loadNotifications('en');
        final pending =
            Completer<Either<Failure, PaginatedResponse<NotificationModel>>>();
        when(
          () => mockRepository.getNotifications('ar', page: 1, pageSize: 20),
        ).thenAnswer((_) => pending.future);
        final loading = cubit.loadNotifications('ar');
        final closing = cubit.close();
        pending.complete(
          Right(
            PaginatedResponse<NotificationModel>(
              items: [testNotification.copyWith(id: 'late')],
              totalCount: 1,
              page: 1,
              pageSize: 20,
            ),
          ),
        );
        await loading;
        expect(cubit.state.notifications.single.id, 'notif_1');
        expect(cubit.isClosed, isFalse);
        cancellation.complete();
        await closing;
        await stream.close();
      },
    );

    PaginatedResponse<NotificationModel> page(
      String id, {
      int number = 1,
      int total = 1,
    }) => PaginatedResponse(
      items: [testNotification.copyWith(id: id)],
      totalCount: total,
      page: number,
      pageSize: 20,
    );

    test(
      'a late first page cannot replace the newer language request',
      () async {
        final old =
            Completer<Either<Failure, PaginatedResponse<NotificationModel>>>();
        when(
          () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
        ).thenAnswer((_) => old.future);
        when(
          () => mockRepository.getNotifications('ar', page: 1, pageSize: 20),
        ).thenAnswer((_) async => Right(page('arabic')));
        final pending = cubit.loadNotifications('en');
        await cubit.loadNotifications('ar');
        old.complete(Right(page('old-english')));
        await pending;
        expect(cubit.state.notifications.single.id, 'arabic');
      },
    );

    test('a late next page cannot append to a refreshed first page', () async {
      final old =
          Completer<Either<Failure, PaginatedResponse<NotificationModel>>>();
      when(
        () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
      ).thenAnswer((_) async => Right(page('initial', total: 21)));
      when(
        () => mockRepository.getNotifications('en', page: 2, pageSize: 20),
      ).thenAnswer((_) => old.future);
      await cubit.loadNotifications('en');
      final pending = cubit.loadMoreNotifications('en');
      when(
        () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
      ).thenAnswer((_) async => Right(page('refreshed')));
      await cubit.refreshNotifications('en');
      old.complete(Right(page('stale-page', number: 2, total: 21)));
      await pending;
      expect(cubit.state.notifications.map((n) => n.id), ['refreshed']);
      expect(cubit.state.page, 1);
      expect(cubit.state.isLoadingMore, isFalse);
    });

    test(
      'bulk read failure preserves notifications arriving during the request',
      () async {
        final pending = Completer<Either<Failure, void>>();
        when(
          () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
        ).thenAnswer((_) async => Right(page('initial')));
        await cubit.loadNotifications('en');
        when(
          () => mockRepository.markAllAsRead(),
        ).thenAnswer((_) => pending.future);
        cubit.markAllAsRead();
        when(
          () => mockRepository.getNotifications('en', page: 1, pageSize: 20),
        ).thenAnswer(
          (_) async => Right(
            PaginatedResponse(
              items: [
                testNotification.copyWith(id: 'new'),
                testNotification.copyWith(id: 'initial', isRead: true),
              ],
              totalCount: 2,
              page: 1,
              pageSize: 20,
            ),
          ),
        );
        await cubit.refreshNotifications('en');
        pending.complete(const Left(ServerFailure('offline')));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.notifications.map((n) => n.id), ['new', 'initial']);
        expect(cubit.state.notifications.last.isRead, isFalse);
      },
    );

    test('initial state is correct', () {
      expect(cubit.state.status, NotificationsStatus.initial);
      expect(cubit.state.notifications, isEmpty);
      expect(cubit.state.hasMore, isTrue);
    });

    test('loadNotifications emits [loading, success] on success', () async {
      when(
        () => mockRepository.getNotifications(
          'en',
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          ),
        ),
      );

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
      when(
        () => mockRepository.getNotifications(
          'en',
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('Failed to load')));

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
      when(
        () => mockRepository.getNotifications(
          'en',
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          ),
        ),
      );
      await cubit.loadNotifications('en');

      when(
        () => mockRepository.markAsRead('notif_1'),
      ).thenAnswer((_) async => const Right(null));

      cubit.markAsRead('notif_1');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isTrue);
      verify(() => mockRepository.markAsRead('notif_1')).called(1);
    });

    test(
      'markAsRead duplicate / race condition calls repository ONLY once',
      () async {
        when(
          () => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => Right(
            PaginatedResponse<NotificationModel>(
              items: [testNotification],
              totalCount: 1,
              page: 1,
              pageSize: 20,
            ),
          ),
        );
        await cubit.loadNotifications('en');

        when(() => mockRepository.markAsRead('notif_1')).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return const Right(null);
        });

        // Simultaneous dual invocation
        cubit.markAsRead('notif_1');
        cubit.markAsRead('notif_1');

        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(cubit.state.notifications.first.isRead, isTrue);
        verify(() => mockRepository.markAsRead('notif_1')).called(1);
      },
    );

    test('markAsRead failure rolls back optimistic update to unread', () async {
      when(
        () => mockRepository.getNotifications(
          'en',
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          ),
        ),
      );
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAsRead('notif_1')).thenAnswer(
        (_) async => const Left(ServerFailure('Database update failed')),
      );

      cubit.markAsRead('notif_1');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isFalse);
      expect(cubit.state.errorMessage, equals('Database update failed'));
    });

    test(
      'markAllAsRead duplicate / race condition calls repository ONLY once',
      () async {
        when(
          () => mockRepository.getNotifications(
            'en',
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => Right(
            PaginatedResponse<NotificationModel>(
              items: [testNotification],
              totalCount: 1,
              page: 1,
              pageSize: 20,
            ),
          ),
        );
        await cubit.loadNotifications('en');

        when(() => mockRepository.markAllAsRead()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return const Right(null);
        });

        // Simultaneous dual invocation
        cubit.markAllAsRead();
        cubit.markAllAsRead();

        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(cubit.state.notifications.every((n) => n.isRead), isTrue);
        verify(() => mockRepository.markAllAsRead()).called(1);
      },
    );

    test('markAllAsRead failure rolls back optimistic update', () async {
      when(
        () => mockRepository.getNotifications(
          'en',
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PaginatedResponse<NotificationModel>(
            items: [testNotification],
            totalCount: 1,
            page: 1,
            pageSize: 20,
          ),
        ),
      );
      await cubit.loadNotifications('en');

      when(() => mockRepository.markAllAsRead()).thenAnswer(
        (_) async => const Left(ServerFailure('Bulk update failed')),
      );

      cubit.markAllAsRead();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.notifications.first.isRead, isFalse);
      expect(cubit.state.errorMessage, equals('Bulk update failed'));
    });
  });
}
