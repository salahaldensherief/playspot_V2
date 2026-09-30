import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
    address: 'Cairo',
    openingTime: '10:00:00',
    closingTime: '03:00:00',
  );

  const room = RoomModel(
    id: 'room-1',
    nameEn: 'VIP Room',
    nameAr: 'غرفة VIP',
    roomNumber: '1',
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

  group('QuickRebookCubit Smart Scan & Circular Distance Tests', () {
    test('selects closest slot across midnight boundary (00:30 when target was 23:30)', () async {
      when(() => mockPrepare(any())).thenAnswer((_) async => Right(setup));

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
      expect(
        cubit.state.selectedSlot,
        const TimeOfDay(hour: 0, minute: 30),
      );
    });

    test('scans future candidate dates when today has no slots and picks candidate with slots', () async {
      when(() => mockPrepare(any())).thenAnswer((_) async => Right(setup));

      final today = DateTime.now();

      // Today has empty slots
      when(
        () => mockGetSlots(
          loungeId: any(named: 'loungeId'),
          roomId: any(named: 'roomId'),
          date: any(that: isA<DateTime>().having((d) => d.day, 'day', today.day)),
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
          date: any(that: isA<DateTime>().having((d) => d.day, 'day', tomorrow.day)),
          openingTime: any(named: 'openingTime'),
          closingTime: any(named: 'closingTime'),
          durationMinutes: any(named: 'durationMinutes'),
        ),
      ).thenAnswer((_) async => const Right([
            TimeOfDay(hour: 23, minute: 0),
            TimeOfDay(hour: 23, minute: 30),
          ]));

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
      ).thenAnswer((_) async => const Right([]));

      await cubit.initQuickRebook(pastBooking);

      expect(cubit.state.status, QuickRebookStatus.ready);
      expect(cubit.state.availableSlots.isNotEmpty, isTrue);
      expect(cubit.state.selectedSlot, const TimeOfDay(hour: 23, minute: 30));
      expect(cubit.state.suggestedDates.isNotEmpty, isTrue);
    });
  });
}
