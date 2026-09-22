import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/active_session/domain/repositories/active_session_repository.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/usecases/extend_session_time_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_lounge_menu_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/place_session_order_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/request_session_extension_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/request_staff_assistance_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/stream_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/submit_lounge_review_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/watch_user_active_session_usecase.dart';
import 'package:playspot/features/active_session/presentation/active_session_cubit.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';

class MockActiveSessionRepository extends Mock implements ActiveSessionRepository {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  late MockActiveSessionRepository mockRepository;
  late ActiveSessionCubit cubit;

  final testSession = ActiveSession(
    bookingId: 'b_100',
    loungeId: 'l_200',
    loungeName: 'Test Lounge',
    roomName: 'Room 1',
    deviceName: 'PS5',
    startTime: DateTime.now().subtract(const Duration(minutes: 10)),
    endTime: DateTime.now().add(const Duration(minutes: 50)),
    basePrice: 120.0,
    status: 'in_progress',
  );

  setUp(() {
    mockRepository = MockActiveSessionRepository();
    when(() => mockRepository.watchUserActiveSession())
        .thenAnswer((_) => Stream.value(null));
    when(() => mockRepository.streamActiveSession(any()))
        .thenAnswer((_) => Stream.value(testSession));
    when(() => mockRepository.getActiveSession(bookingId: any(named: 'bookingId')))
        .thenAnswer((_) async => Right(testSession));
    when(() => mockRepository.getLoungeMenu(any()))
        .thenAnswer((_) async => const Right([]));

    cubit = ActiveSessionCubit(
      getActiveSessionUseCase: GetActiveSessionUseCase(mockRepository),
      watchUserActiveSessionUseCase: WatchUserActiveSessionUseCase(mockRepository),
      streamActiveSessionUseCase: StreamActiveSessionUseCase(mockRepository),
      extendSessionTimeUseCase: ExtendSessionTimeUseCase(mockRepository),
      requestSessionExtensionUseCase: RequestSessionExtensionUseCase(mockRepository),
      placeSessionOrderUseCase: PlaceSessionOrderUseCase(mockRepository),
      getLoungeMenuUseCase: GetLoungeMenuUseCase(mockRepository),
      requestStaffAssistanceUseCase: RequestStaffAssistanceUseCase(mockRepository),
      submitLoungeReviewUseCase: SubmitLoungeReviewUseCase(mockRepository),
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('ActiveSessionCubit Unit Tests', () {
    test('initial state is correct', () {
      expect(cubit.state.status, ActiveSessionStatus.initial);
      expect(cubit.state.session, null);
      expect(cubit.state.extendStatus, ActionStatus.initial);
      expect(cubit.state.orderStatus, ActionStatus.initial);
    });

    test('loadActiveSession emits [loading, loaded] when active session exists', () async {
      when(() => mockRepository.getActiveSession(bookingId: 'b_100'))
          .thenAnswer((_) async => Right(testSession));

      final expectedStates = [
        const ActiveSessionState(status: ActiveSessionStatus.loading),
        ActiveSessionState(
          status: ActiveSessionStatus.loaded,
          session: testSession,
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadActiveSession(bookingId: 'b_100');
    });

    test('loadActiveSession emits [loading, empty] when no session exists', () async {
      when(() => mockRepository.getActiveSession(bookingId: null))
          .thenAnswer((_) async => const Right(null));

      final expectedStates = [
        const ActiveSessionState(status: ActiveSessionStatus.loading),
        const ActiveSessionState(
          status: ActiveSessionStatus.empty,
          session: null,
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadActiveSession(bookingId: null);
    });

    test('extendTime emits loading and then success when extendTime succeeds', () async {
      await cubit.loadActiveSession(bookingId: 'b_100');

      when(() => mockRepository.extendTime(
            'b_100',
            30,
            25.0,
          )).thenAnswer((_) async => const Right(null));

      final extendFuture = cubit.extendTime(30, 25.0);
      await extendFuture;

      verify(() => mockRepository.extendTime(
            'b_100',
            30,
            25.0,
          )).called(1);
    });

    test('extendTime emits error when extendTime fails', () async {
      await cubit.loadActiveSession(bookingId: 'b_100');

      when(() => mockRepository.extendTime(
            'b_100',
            30,
            25.0,
          )).thenAnswer((_) async => const Left(ServerFailure('Network error')));

      await cubit.extendTime(30, 25.0);

      expect(cubit.state.extendStatus, ActionStatus.error);
      expect(cubit.state.errorMessage, 'Network error');
    });
  });
}
