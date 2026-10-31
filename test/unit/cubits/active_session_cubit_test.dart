import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/active_session/domain/repositories/active_session_repository.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/entities/canteen_combo.dart';
import 'package:playspot/features/active_session/domain/entities/order_item.dart';
import 'package:playspot/features/active_session/domain/entities/out_of_stock_item.dart';
import 'package:playspot/features/active_session/domain/entities/upsell_suggestion.dart';
import 'package:playspot/features/active_session/data/models/canteen_menu_data_model.dart';
import 'package:playspot/features/active_session/domain/usecases/extend_session_time_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_canteen_menu_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_lounge_menu_usecase.dart';
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

class MockActiveSessionRepository extends Mock
    implements ActiveSessionRepository {}

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    // GetStorage 2.1.1 holds a RandomAccessFile with no public close API.
    // Windows releases it when this test worker exits; Unix permits unlinking.
    if (!Platform.isWindows) await storageDirectory.delete(recursive: true);
  });

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
    when(
      () => mockRepository.watchUserActiveSession(),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepository.streamActiveSession(any()),
    ).thenAnswer((_) => Stream.value(testSession));
    when(
      () => mockRepository.getActiveSession(bookingId: any(named: 'bookingId')),
    ).thenAnswer((_) async => Right(testSession));
    when(
      () => mockRepository.getLoungeMenu(any()),
    ).thenAnswer((_) async => const Right([]));
    when(() => mockRepository.getCanteenMenu(any())).thenAnswer(
      (_) async => const Right(CanteenMenuData(extras: [], combos: [])),
    );
    when(
      () => mockRepository.getUpsellSuggestions(any()),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => mockRepository.recordUpsellEvent(
        ruleId: any(named: 'ruleId'),
        bookingId: any(named: 'bookingId'),
        event: any(named: 'event'),
        canteenOrderId: any(named: 'canteenOrderId'),
        amount: any(named: 'amount'),
      ),
    ).thenAnswer((_) async => const Right(null));

    cubit = ActiveSessionCubit(
      getActiveSessionUseCase: GetActiveSessionUseCase(mockRepository),
      watchUserActiveSessionUseCase: WatchUserActiveSessionUseCase(
        mockRepository,
      ),
      streamActiveSessionUseCase: StreamActiveSessionUseCase(mockRepository),
      extendSessionTimeUseCase: ExtendSessionTimeUseCase(mockRepository),
      requestSessionExtensionUseCase: RequestSessionExtensionUseCase(
        mockRepository,
      ),
      placeSessionOrderUseCase: PlaceSessionOrderUseCase(mockRepository),
      getLoungeMenuUseCase: GetLoungeMenuUseCase(mockRepository),
      getCanteenMenuUseCase: GetCanteenMenuUseCase(mockRepository),
      getUpsellSuggestionsUseCase: GetUpsellSuggestionsUseCase(mockRepository),
      recordUpsellEventUseCase: RecordUpsellEventUseCase(mockRepository),
      requestStaffAssistanceUseCase: RequestStaffAssistanceUseCase(
        mockRepository,
      ),
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
      expect(cubit.state.combos, isEmpty);
      expect(cubit.state.unavailableItems, isEmpty);
    });

    test(
      'loadActiveSession emits [loading, loaded] when active session exists',
      () async {
        when(
          () => mockRepository.getActiveSession(bookingId: 'b_100'),
        ).thenAnswer((_) async => Right(testSession));

        final expectedStates = [
          const ActiveSessionState(status: ActiveSessionStatus.loading),
          ActiveSessionState(
            status: ActiveSessionStatus.loaded,
            session: testSession,
          ),
        ];

        expectLater(cubit.stream, emitsInOrder(expectedStates));

        await cubit.loadActiveSession(bookingId: 'b_100');
      },
    );

    test('loadMenu populates extras and combos correctly', () async {
      const testExtra = ExtraModel(
        id: 'e1',
        name: 'Pepsi',
        price: 20.0,
        category: 'drinks',
      );
      const testCombo = CanteenCombo(
        id: 'c1',
        nameAr: 'عرض التوفير',
        price: 50.0,
        separateItemsPrice: 65.0,
        savings: 15.0,
        items: [
          CanteenComboComponent(extraId: 'e1', nameAr: 'بيبسي', quantity: 2),
        ],
      );

      when(() => mockRepository.getCanteenMenu('l_200')).thenAnswer(
        (_) async => const Right(
          CanteenMenuData(extras: [testExtra], combos: [testCombo]),
        ),
      );

      await cubit.loadMenu('l_200');

      expect(cubit.state.menuStatus, ActionStatus.success);
      expect(cubit.state.menu.length, 1);
      expect(cubit.state.combos.length, 1);
      expect(cubit.state.combos.first.savings, 15.0);
    });

    test(
      'placeOrder with CanteenOutOfStockFailure populates unavailableItems without clearing cart',
      () async {
        await cubit.loadActiveSession(bookingId: 'b_100');

        const unavailable = OutOfStockItem(
          id: 'e1',
          name: 'بيبسي',
          available: 2,
          requested: 5,
        );

        when(() => mockRepository.placeOrder(any(), any())).thenAnswer(
          (_) async => const Left(
            CanteenOutOfStockFailure(
              message: 'Some items are out of stock',
              unavailableItems: [unavailable],
            ),
          ),
        );

        final orderItem = const OrderItem(
          id: 'e1',
          name: 'Pepsi',
          price: 20.0,
          quantity: 5,
        );

        await cubit.placeOrder([orderItem]);

        expect(cubit.state.orderStatus, ActionStatus.error);
        expect(cubit.state.unavailableItems.length, 1);
        expect(cubit.state.unavailableItems.first.available, 2);
      },
    );

    test('recordUpsellImpression caps at 2 impressions per booking', () async {
      await cubit.loadActiveSession(bookingId: 'b_100');

      const suggestion = UpsellSuggestion(
        ruleId: 'r1',
        suggestionType: 'combo',
        targetId: 'c1',
        nameAr: 'كومبو الألعاب',
        originalPrice: 60.0,
        discountPercent: 10.0,
        finalPrice: 54.0,
      );

      expect(cubit.state.upsellImpressionsCount, 0);

      await cubit.recordUpsellImpression(suggestion);
      expect(cubit.state.upsellImpressionsCount, 1);

      await cubit.recordUpsellImpression(suggestion);
      expect(cubit.state.upsellImpressionsCount, 2);

      // Third attempt should be ignored
      await cubit.recordUpsellImpression(suggestion);
      expect(cubit.state.upsellImpressionsCount, 2);

      verify(
        () => mockRepository.recordUpsellEvent(
          ruleId: 'r1',
          bookingId: 'b_100',
          event: 'shown',
        ),
      ).called(2);
    });

    test(
      'requestExtension emits success and reloads session when repository succeeds',
      () async {
        await cubit.loadActiveSession(bookingId: 'b_100');

        when(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 30,
          ),
        ).thenAnswer((_) async => const Right(null));

        await cubit.requestExtension(30);

        expect(cubit.state.extendStatus, ActionStatus.success);
        verify(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 30,
          ),
        ).called(1);
      },
    );

    test(
      'requestExtension emits error with failure message when repository fails',
      () async {
        await cubit.loadActiveSession(bookingId: 'b_100');

        when(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 15,
          ),
        ).thenAnswer(
          (_) async =>
              const Left(ServerFailure('Extension request already pending')),
        );

        await cubit.requestExtension(15);

        expect(cubit.state.extendStatus, ActionStatus.error);
        expect(cubit.state.errorMessage, 'Extension request already pending');
        verify(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 15,
          ),
        ).called(1);
      },
    );

    test(
      'extendTime delegates directly to requestExtension without client pricing',
      () async {
        await cubit.loadActiveSession(bookingId: 'b_100');

        when(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 60,
          ),
        ).thenAnswer((_) async => const Right(null));

        await cubit.extendTime(60);

        expect(cubit.state.extendStatus, ActionStatus.success);
        verify(
          () => mockRepository.requestExtension(
            bookingId: 'b_100',
            requestedMinutes: 60,
          ),
        ).called(1);
      },
    );
  });
}
