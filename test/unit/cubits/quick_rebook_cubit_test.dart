import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/domain/entities/quick_rebook_setup.dart';
import 'package:playspot/features/my_bookings/domain/usecases/build_quick_rebook_checkout_usecase.dart';
import 'package:playspot/features/my_bookings/domain/usecases/get_quick_rebook_slots_usecase.dart';
import 'package:playspot/features/my_bookings/domain/usecases/prepare_quick_rebook_usecase.dart';
import 'package:playspot/features/my_bookings/presentation/quick_rebook_cubit.dart';
import 'package:playspot/features/my_bookings/presentation/quick_rebook_state.dart';

class MockPrepareQuickRebookUseCase extends Mock
    implements PrepareQuickRebookUseCase {}

class MockGetQuickRebookSlotsUseCase extends Mock
    implements GetQuickRebookSlotsUseCase {}

class MockBuildQuickRebookCheckoutUseCase extends Mock
    implements BuildQuickRebookCheckoutUseCase {}

void main() {
  late MockPrepareQuickRebookUseCase mockPrepare;
  late MockGetQuickRebookSlotsUseCase mockGetSlots;
  late MockBuildQuickRebookCheckoutUseCase mockCheckout;
  late QuickRebookCubit cubit;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockPrepare = MockPrepareQuickRebookUseCase();
    mockGetSlots = MockGetQuickRebookSlotsUseCase();
    mockCheckout = MockBuildQuickRebookCheckoutUseCase();

    cubit = QuickRebookCubit(
      prepareQuickRebook: mockPrepare,
      getQuickRebookSlots: mockGetSlots,
      buildQuickRebookCheckout: mockCheckout,
    );
  });

  tearDown(() {
    cubit.close();
  });

  final pastBooking = BookingModel.fromJson({
    'id': 'booking-123',
    'lounge_id': 'lounge-1',
    'room_id': 'room-1',
    'date': '2026-09-20',
    'start_time': '23:30:00',
    'end_time': '00:30:00',
    'status': 'completed',
    'payment_status': 'paid',
    'total_price': 100,
    'play_mode': 'single',
    'controllers_count': 2,
    'extra_controllers': 0,
    'rooms': {
      'id': 'room-1',
      'name_en': 'VIP Room',
      'controllers_count': 2,
      'screen_size': '65"',
    },
    'lounges': {
      'id': 'lounge-1',
      'name': 'GameSpot',
      'location': 'Cairo',
      'opening_time': '10:00:00',
      'closing_time': '03:00:00',
    },
  });

  const lounge = LoungeModel(
    id: 'lounge-1',
    name: 'GameSpot',
    location: 'Cairo',
    imageUrl: '',
    rating: 0,
    distance: 0,
    pricePerHour: 100,
    isOpen: true,
    openingTime: '10:00:00',
    closingTime: '03:00:00',
  );

  const room = RoomModel(
    id: 'room-1',
    nameEn: 'VIP Room',
    nameAr: 'غرفة VIP',
    loungeId: 'lounge-1',
    activityNames: [],
    maxCapacity: 4,
    isAvailable: true,
    images: [],
    featuresAr: [],
    featuresEn: [],
    controllersCount: 2,
    hourlyRateSingle: 100,
    hourlyRateMulti: 150,
  );

  final setup = QuickRebookSetup(
    pastBooking: pastBooking,
    lounge: lounge,
    room: room,
    availableExtras: const [],
    selectedAddonQuantities: const {},
    removedAddonNames: const [],
    durationMinutes: 60,
    playMode: 'single',
    extraControllers: 0,
  );

  void stubSlots(
    Future<Either<Failure, List<TimeOfDay>>> Function(Invocation) answer,
  ) {
    when(
      () => mockGetSlots(
        loungeId: any(named: 'loungeId'),
        roomId: any(named: 'roomId'),
        date: any(named: 'date'),
        openingTime: any(named: 'openingTime'),
        closingTime: any(named: 'closingTime'),
        durationMinutes: any(named: 'durationMinutes'),
      ),
    ).thenAnswer(answer);
  }

  test(
    'setup transport failure offers error recovery instead of unavailable',
    () async {
      when(
        () => mockPrepare(pastBooking),
      ).thenAnswer((_) async => const Left(NetworkFailure('load failed')));
      await cubit.initQuickRebook(pastBooking);
      expect(cubit.state.status, QuickRebookStatus.error);
      expect(cubit.state.errorMessage, 'load failed');
    },
  );

  test('confirmed missing room keeps unavailable status', () async {
    when(() => mockPrepare(pastBooking)).thenAnswer(
      (_) async => const Left(ServerFailure('quickRebookRoomUnavailable')),
    );
    await cubit.initQuickRebook(pastBooking);
    expect(cubit.state.status, QuickRebookStatus.unavailable);
  });

  for (final action in ['initial load', 'change date', 'change duration']) {
    test(
      '$action surfaces slot failure instead of an empty calendar',
      () async {
        when(
          () => mockPrepare(pastBooking),
        ).thenAnswer((_) async => Right(setup));
        var requests = 0;
        stubSlots((_) async {
          requests++;
          return const Right([TimeOfDay(hour: 18, minute: 0)]);
        });
        if (action != 'initial load') await cubit.initQuickRebook(pastBooking);
        requests = 0;
        stubSlots((_) async {
          requests++;
          return const Left(ServerFailure('fixture request failed'));
        });
        if (action == 'initial load') {
          await cubit.initQuickRebook(pastBooking);
        } else if (action == 'change date') {
          await cubit.changeDate(DateTime.now().add(const Duration(days: 1)));
        } else {
          await cubit.updateDuration(90);
        }
        expect(cubit.state.status, QuickRebookStatus.error);
        expect(cubit.state.errorMessage, 'fixture request failed');
        expect(cubit.state.availableSlots, isEmpty);
        expect(cubit.state.selectedSlot, isNull);
        expect(requests, 1);
        expect(await cubit.prepareCheckout(), isNull);
      },
    );
  }

  test(
    'candidate scan stops on failure instead of claiming future capacity',
    () async {
      when(
        () => mockPrepare(pastBooking),
      ).thenAnswer((_) async => Right(setup));
      var requests = 0;
      stubSlots(
        (_) async => ++requests == 1
            ? const Right([])
            : const Left(ServerFailure('fixture scan failure')),
      );
      await cubit.initQuickRebook(pastBooking);
      expect(cubit.state.status, QuickRebookStatus.error);
      expect(requests, 2);
    },
  );

  test('successful retry clears an earlier failure', () async {
    when(() => mockPrepare(pastBooking)).thenAnswer((_) async => Right(setup));
    stubSlots((_) async => const Left(ServerFailure('fixture error')));
    await cubit.initQuickRebook(pastBooking);
    stubSlots((_) async => const Right([TimeOfDay(hour: 18, minute: 0)]));
    await cubit.initQuickRebook(pastBooking);
    expect(cubit.state.status, QuickRebookStatus.ready);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.selectedSlot, const TimeOfDay(hour: 18, minute: 0));
  });

  test('late failed request cannot replace a newer successful date', () async {
    when(() => mockPrepare(pastBooking)).thenAnswer((_) async => Right(setup));
    stubSlots((_) async => const Right([TimeOfDay(hour: 18, minute: 0)]));
    await cubit.initQuickRebook(pastBooking);
    final late = Completer<Either<Failure, List<TimeOfDay>>>();
    var requests = 0;
    stubSlots(
      (_) => ++requests == 1
          ? late.future
          : Future.value(const Right([TimeOfDay(hour: 20, minute: 0)])),
    );
    final first = cubit.changeDate(DateTime(2026, 11, 1));
    await cubit.changeDate(DateTime(2026, 11, 2));
    late.complete(const Left(ServerFailure('stale fixture failure')));
    await first;
    expect(cubit.state.status, QuickRebookStatus.ready);
    expect(cubit.state.selectedDate, DateTime(2026, 11, 2));
    expect(cubit.state.errorMessage, isNull);
  });

  group('QuickRebookCubit Smart Scan & Circular Distance Tests', () {
    test(
      'selects closest slot across midnight boundary (00:30 when target was 23:30)',
      () async {
        when(
          () => mockPrepare(pastBooking),
        ).thenAnswer((_) async => Right(setup));

        // Available slots include 14:00, 16:00, and 00:30
        when(
          () => mockGetSlots(
            loungeId: any(named: 'loungeId'),
            roomId: any(named: 'roomId'),
            date: any(named: 'date'),
            openingTime: any(named: 'openingTime'),
            closingTime: any(named: 'closingTime'),
            durationMinutes: any(named: 'durationMinutes'),
          ),
        ).thenAnswer(
          (_) async => const Right([
            TimeOfDay(hour: 14, minute: 0),
            TimeOfDay(hour: 16, minute: 0),
            TimeOfDay(hour: 0, minute: 30),
          ]),
        );

        await cubit.initQuickRebook(pastBooking);

        expect(cubit.state.status, QuickRebookStatus.ready);
        expect(cubit.state.selectedSlot, const TimeOfDay(hour: 0, minute: 30));
      },
    );

    test(
      'scans future candidate dates when today has no slots and picks candidate with slots',
      () async {
        when(
          () => mockPrepare(pastBooking),
        ).thenAnswer((_) async => Right(setup));

        final today = DateTime.now();

        // Today has empty slots
        when(
          () => mockGetSlots(
            loungeId: any(named: 'loungeId'),
            roomId: any(named: 'roomId'),
            date: any(
              named: 'date',
              that: isA<DateTime>().having((d) => d.day, 'day', today.day),
            ),
            openingTime: any(named: 'openingTime'),
            closingTime: any(named: 'closingTime'),
            durationMinutes: any(named: 'durationMinutes'),
          ),
        ).thenAnswer((_) async => const Right([]));

        // Tomorrow has slots
        final tomorrow = today.add(const Duration(days: 1));
        when(
          () => mockGetSlots(
            loungeId: any(named: 'loungeId'),
            roomId: any(named: 'roomId'),
            date: any(
              named: 'date',
              that: isA<DateTime>().having((d) => d.day, 'day', tomorrow.day),
            ),
            openingTime: any(named: 'openingTime'),
            closingTime: any(named: 'closingTime'),
            durationMinutes: any(named: 'durationMinutes'),
          ),
        ).thenAnswer(
          (_) async => const Right([
            TimeOfDay(hour: 23, minute: 0),
            TimeOfDay(hour: 23, minute: 30),
          ]),
        );

        // Other dates
        when(
          () => mockGetSlots(
            loungeId: any(named: 'loungeId'),
            roomId: any(named: 'roomId'),
            date: any(named: 'date'),
            openingTime: any(named: 'openingTime'),
            closingTime: any(named: 'closingTime'),
            durationMinutes: any(named: 'durationMinutes'),
          ),
        ).thenAnswer((invocation) async {
          final date = invocation.namedArguments[#date] as DateTime;
          if (DateUtils.isSameDay(date, tomorrow)) {
            return const Right([
              TimeOfDay(hour: 23, minute: 0),
              TimeOfDay(hour: 23, minute: 30),
            ]);
          }
          return const Right([]);
        });

        await cubit.initQuickRebook(pastBooking);

        expect(cubit.state.status, QuickRebookStatus.ready);
        expect(cubit.state.availableSlots.isNotEmpty, isTrue);
        expect(cubit.state.selectedSlot, const TimeOfDay(hour: 23, minute: 30));
        expect(cubit.state.suggestedDates.isNotEmpty, isTrue);
      },
    );
  });
}
