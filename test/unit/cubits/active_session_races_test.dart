import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/cache/caching_key.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/entities/order_item.dart';
import 'package:playspot/features/active_session/data/models/canteen_menu_data_model.dart';
import 'package:playspot/features/active_session/domain/usecases/extend_session_time_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_canteen_menu_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_upsell_suggestions_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/place_session_order_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/record_upsell_event_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/request_session_extension_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/request_staff_assistance_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/stream_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/submit_lounge_review_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/watch_user_active_session_usecase.dart';
import 'package:playspot/features/active_session/presentation/active_session_cubit.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'active_session_cubit_test.dart' show MockActiveSessionRepository;

void main() {
  late Directory storageDirectory;
  const storageChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'playspot_session_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storageChannel,
          (_) async => storageDirectory.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() async {
    // GetStorage 2.1.1 starts an unawaited .bak write in StorageImpl.flush.
    // It may request path_provider after write/remove futures have resolved.
    // Keep this test-worker's mock and its temp directory alive until exit.
    // Removing the handler here causes intermittent MissingPluginException.
    await Future<void>.delayed(Duration.zero);
    await GetStorage().queue.add(() async {});
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  late MockActiveSessionRepository repo;
  late ActiveSessionCubit cubit;
  late StreamController<ActiveSession?> watch;
  late StreamController<ActiveSession> updates;
  final a = ActiveSession(
    bookingId: 'a',
    loungeId: 'la',
    loungeName: 'A',
    roomName: 'PS5',
    deviceName: 'PS5',
    startTime: DateTime(2026),
    endTime: DateTime(2027),
    basePrice: 100,
    status: 'in_progress',
  );
  final b = a.copyWith(bookingId: 'b', loungeId: 'lb');

  setUp(() {
    repo = MockActiveSessionRepository();
    watch = StreamController<ActiveSession?>.broadcast();
    updates = StreamController<ActiveSession>.broadcast();
    when(() => repo.watchUserActiveSession()).thenAnswer((_) => watch.stream);
    when(
      () => repo.streamActiveSession(any()),
    ).thenAnswer((_) => updates.stream);
    when(
      () => repo.getActiveSession(bookingId: any(named: 'bookingId')),
    ).thenAnswer(
      (call) async => Right(call.namedArguments[#bookingId] == 'b' ? b : a),
    );
    when(() => repo.getCanteenMenu(any())).thenAnswer(
      (_) async => const Right(CanteenMenuData(extras: [], combos: [])),
    );
    when(
      () => repo.getUpsellSuggestions(any()),
    ).thenAnswer((_) async => const Right([]));
    cubit = ActiveSessionCubit(
      getActiveSessionUseCase: GetActiveSessionUseCase(repo),
      watchUserActiveSessionUseCase: WatchUserActiveSessionUseCase(repo),
      streamActiveSessionUseCase: StreamActiveSessionUseCase(repo),
      extendSessionTimeUseCase: ExtendSessionTimeUseCase(repo),
      requestSessionExtensionUseCase: RequestSessionExtensionUseCase(repo),
      placeSessionOrderUseCase: PlaceSessionOrderUseCase(repo),
      getCanteenMenuUseCase: GetCanteenMenuUseCase(repo),
      getUpsellSuggestionsUseCase: GetUpsellSuggestionsUseCase(repo),
      recordUpsellEventUseCase: RecordUpsellEventUseCase(repo),
      requestStaffAssistanceUseCase: RequestStaffAssistanceUseCase(repo),
      submitLoungeReviewUseCase: SubmitLoungeReviewUseCase(repo),
    );
  });
  tearDown(() async {
    await cubit.close();
    await watch.close();
    await updates.close();
  });

  test('copyWith explicitly clears nullable session and errors', () {
    final state = ActiveSessionState(
      session: a,
      completedSession: a,
      errorMessage: 'error',
    );
    final cleared = state.copyWith(
      session: null,
      completedSession: null,
      errorMessage: null,
    );
    expect(cleared.session, isNull);
    expect(cleared.completedSession, isNull);
    expect(cleared.errorMessage, isNull);
    expect(state.copyWith().session, a);
  });

  test('last fetch wins and old response cannot replace new session', () async {
    final pending = Completer<Either<Failure, ActiveSession?>>();
    when(
      () => repo.getActiveSession(bookingId: 'a'),
    ).thenAnswer((_) => pending.future);
    final old = cubit.loadActiveSession(bookingId: 'a');
    await cubit.loadActiveSession(bookingId: 'b');
    pending.complete(Right(a));
    await old;
    expect(cubit.state.session, b);
  });

  test(
    'terminal event invalidates pending refresh and clears session',
    () async {
      await cubit.loadActiveSession(bookingId: 'a');
      final pending = Completer<Either<Failure, ActiveSession?>>();
      when(
        () => repo.getActiveSession(bookingId: 'a'),
      ).thenAnswer((_) => pending.future);
      final refresh = cubit.loadActiveSession(bookingId: 'a');
      updates.add(a.copyWith(status: 'cancelled'));
      await Future<void>.delayed(Duration.zero);
      pending.complete(Right(a));
      await refresh;
      expect(cubit.state.status, ActiveSessionStatus.empty);
      expect(cubit.state.session, isNull);
    },
  );

  test('watch removal invalidates initial pending fetch', () async {
    final pending = Completer<Either<Failure, ActiveSession?>>();
    when(
      () => repo.getActiveSession(bookingId: 'a'),
    ).thenAnswer((_) => pending.future);
    final fetch = cubit.loadActiveSession(bookingId: 'a');
    watch.add(null);
    await Future<void>.delayed(Duration.zero);
    pending.complete(Right(a));
    await fetch;
    expect(cubit.state.session, isNull);
    expect(cubit.state.status, ActiveSessionStatus.empty);
  });

  test('menu from old lounge is hidden and late response discarded', () async {
    const extra = ExtraModel(
      id: 'old',
      name: 'Old',
      price: 1,
      category: 'food',
    );
    final pending = Completer<Either<Failure, CanteenMenuData>>();
    when(() => repo.getCanteenMenu('la')).thenAnswer((_) => pending.future);
    await cubit.loadActiveSession(bookingId: 'a');
    await cubit.loadActiveSession(bookingId: 'b');
    pending.complete(const Right(CanteenMenuData(extras: [extra], combos: [])));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.menu, isEmpty);
    await cubit.loadMenu('la');
    verify(() => repo.getCanteenMenu('la')).called(1);
  });

  test(
    'new session resets busy actions and rejects old response even after returning to A',
    () async {
      final pending = Completer<Either<Failure, void>>();
      when(
        () => repo.requestStaffAssistance(
          bookingId: any(named: 'bookingId'),
          callType: any(named: 'callType'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) => pending.future);
      await cubit.loadActiveSession(bookingId: 'a');
      final action = cubit.requestStaffAssistance('help', null);
      await cubit.requestStaffAssistance('help', null);
      verify(
        () => repo.requestStaffAssistance(
          bookingId: 'a',
          callType: 'help',
          notes: null,
        ),
      ).called(1);
      await cubit.loadActiveSession(bookingId: 'b');
      expect(cubit.state.staffRequestStatus, ActionStatus.initial);
      expect(cubit.state.extendStatus, ActionStatus.initial);
      expect(cubit.state.orderStatus, ActionStatus.initial);
      await cubit.loadActiveSession(bookingId: 'a');
      pending.complete(const Right(null));
      await action;
      expect(cubit.state.staffRequestStatus, ActionStatus.initial);
    },
  );

  test('dispose ignores fetch completion and cancels subscriptions', () async {
    final pending = Completer<Either<Failure, ActiveSession?>>();
    when(
      () => repo.getActiveSession(bookingId: 'a'),
    ).thenAnswer((_) => pending.future);
    final fetch = cubit.loadActiveSession(bookingId: 'a');
    await cubit.close();
    pending.complete(Right(a));
    await fetch;
    expect(cubit.state.session, isNull);
    expect(watch.hasListener, isFalse);
    expect(updates.hasListener, isFalse);
  });

  for (final action in ['extend', 'request', 'order']) {
    test(
      '$action resets loading on transition and ignores disposed reply',
      () async {
        final pending = Completer<Either<Failure, void>>();
        when(
          () => repo.extendTime(any(), any(), any()),
        ).thenAnswer((_) => pending.future);
        when(
          () => repo.requestExtension(
            bookingId: any(named: 'bookingId'),
            requestedMinutes: any(named: 'requestedMinutes'),
          ),
        ).thenAnswer((_) => pending.future);
        when(
          () => repo.placeOrder(any(), any()),
        ).thenAnswer((_) => pending.future);
        await cubit.loadActiveSession(bookingId: 'a');
        Future<void> submit() => switch (action) {
          'extend' => cubit.extendTime(15, 25),
          'request' => cubit.requestExtension(15),
          _ => cubit.placeOrder(const <OrderItem>[]),
        };
        final request = submit();
        await submit();
        await cubit.loadActiveSession(bookingId: 'b');
        expect(cubit.state.extendStatus, ActionStatus.initial);
        expect(cubit.state.orderStatus, ActionStatus.initial);
        await cubit.close();
        pending.complete(const Right(null));
        await request;
        if (action == 'extend' || action == 'request') {
          verify(
            () => repo.requestExtension(bookingId: 'a', requestedMinutes: 15),
          ).called(1);
        }
        if (action == 'order') {
          verify(() => repo.placeOrder('a', any())).called(1);
        }
      },
    );
  }
  void stubReview(Future<Either<Failure, void>> Function() result) {
    when(
      () => repo.submitLoungeReview(
        loungeId: any(named: 'loungeId'),
        bookingId: any(named: 'bookingId'),
        rating: any(named: 'rating'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer((_) => result());
  }

  test(
    'review pending and failure never mark persisted; retry marks only on success',
    () async {
      await GetStorage().remove(CachingKey.confirmedReviewedBookings);
      final pending = Completer<Either<Failure, void>>();
      stubReview(() => pending.future);
      final request = cubit.submitReview(rating: 5, reviewSession: a);
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings) ?? [],
        isNot(contains('a')),
      );
      pending.complete(const Left(ServerFailure('reviewSubmissionFailed')));
      expect((await request).isLeft(), isTrue);
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings) ?? [],
        isNot(contains('a')),
      );
      stubReview(() async => const Right(null));
      expect(
        (await cubit.submitReview(rating: 5, reviewSession: a)).isRight(),
        isTrue,
      );
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings),
        contains('a'),
      );
    },
  );

  test(
    'two review sheets cannot concurrently submit the same booking',
    () async {
      final pending = Completer<Either<Failure, void>>();
      var calls = 0;
      stubReview(() {
        calls++;
        return pending.future;
      });
      final request = cubit.submitReview(rating: 5, reviewSession: a);
      expect(
        (await cubit.submitReview(rating: 4, reviewSession: a)).isLeft(),
        isTrue,
      );
      expect(calls, 1);
      pending.complete(const Left(ServerFailure('reviewSubmissionFailed')));
      await request;
    },
  );

  test('persisting old review cannot clear a newer active session', () async {
    final pending = Completer<Either<Failure, void>>();
    stubReview(() => pending.future);
    final request = cubit.submitReview(rating: 5, reviewSession: a);
    await cubit.loadActiveSession(bookingId: 'b');
    pending.complete(const Right(null));
    expect((await request).isRight(), isTrue);
    expect(cubit.state.session?.bookingId, 'b');
    expect(
      GetStorage().read<List>(CachingKey.confirmedReviewedBookings),
      contains('a'),
    );
  });

  test(
    'successful review finishes local cache write before returning',
    () async {
      await GetStorage().remove(CachingKey.confirmedReviewedBookings);
      stubReview(() async => const Right(null));

      final result = await cubit.submitReview(rating: 5, reviewSession: a);

      expect(result.isRight(), isTrue);
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings),
        contains('a'),
      );
      // The write has completed, so a subsequent update cannot be undone by
      // a delayed fire-and-forget write from the review submission.
      await GetStorage().write(CachingKey.confirmedReviewedBookings, <String>[
        'another-booking',
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings),
        <String>['another-booking'],
      );
    },
  );

  test(
    'confirmed persistence survives Cubit disposal without emitting',
    () async {
      await GetStorage().remove(CachingKey.confirmedReviewedBookings);
      final pending = Completer<Either<Failure, void>>();
      stubReview(() => pending.future);
      final request = cubit.submitReview(rating: 5, reviewSession: a);
      await cubit.close();
      pending.complete(const Right(null));
      expect((await request).isRight(), isTrue);
      expect(
        GetStorage().read<List>(CachingKey.confirmedReviewedBookings),
        contains('a'),
      );
    },
  );
}
