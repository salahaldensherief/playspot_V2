import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/booking/domain/repositories/booking_waitlist_repository.dart';
import 'package:playspot/features/booking/domain/strategies/booking_slot_strategy.dart';
import 'package:playspot/features/booking/domain/usecases/join_booking_waitlist_usecase.dart';
import 'package:playspot/features/booking/presentation/booking_cubit.dart';
import 'package:playspot/features/booking/presentation/booking_state.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class _Repository extends Mock implements BookingRepository {}

class _Waitlist extends Mock implements BookingWaitlistRepository {}

class _Slots extends Mock implements BookingSlotStrategy {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late BookingCubit cubit;
  final date = DateTime(2030, 1, 10);

  setUpAll(() => registerFallbackValue(date));
  setUp(() async {
    repository = _Repository();
    final slots = _Slots();
    final waitlist = _Waitlist();
    when(
      () => repository.getRoomBookingsForDate(
        any(),
        any(),
        roomId: any(named: 'roomId'),
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.getRoomSlotsWithPrices(
        roomId: any(named: 'roomId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => slots.calculateBookedSlots(
        rawBookings: any(named: 'rawBookings'),
        roomId: any(named: 'roomId'),
        date: any(named: 'date'),
      ),
    ).thenReturn([]);
    when(
      () => repository.quoteBookingPrice(
        roomId: any(named: 'roomId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        playMode: any(named: 'playMode'),
        extraControllers: any(named: 'extraControllers'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('fixture')));
    cubit = BookingCubit(
      repository,
      slots,
      BookingDetailsParams(
        lounge: LoungeModel.fromJson({
          'id': 'l',
          'name': 'Fixture',
          'opening_time': '10:00:00',
          'closing_time': '23:00:00',
        }),
        room: RoomModel.fromJson({'id': 'r', 'lounge_id': 'l'}),
        selectedDate: date,
        extras: const [],
      ),
      joinWaitlist: JoinBookingWaitlistUseCase(waitlist),
      waitlistRepository: waitlist,
    );
    await Future<void>.delayed(Duration.zero);
    cubit.emit(
      cubit.state.copyWith(startTime: const TimeOfDay(hour: 14, minute: 0)),
    );
  });
  tearDown(() => cubit.close());

  void response(Map<String, dynamic> payload) {
    when(
      () => repository.acquireBookingHold(
        roomIds: any(named: 'roomIds'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async => Right(payload));
  }

  test(
    'canonical expires_at accepts a successfully reserved empty slot',
    () async {
      final expiry = DateTime.now().toUtc().add(const Duration(minutes: 10));
      response({
        'success': true,
        'hold_token': 'hold-fixture',
        'expires_at': expiry.toIso8601String(),
      });
      expect(await cubit.verifyAvailabilityBeforeProceed(), isTrue);
      expect(cubit.state.status, BookingStatus.success);
      expect(cubit.state.holdToken, 'hold-fixture');
      expect(cubit.state.holdExpiresAt, expiry);
      expect(cubit.state.heldStartAt, DateTime(2030, 1, 10, 14));
    },
  );

  test(
    'a malformed hold cannot proceed or claim the slot is occupied',
    () async {
      response({'success': true, 'hold_token': 'hold-fixture'});
      expect(await cubit.verifyAvailabilityBeforeProceed(), isFalse);
      expect(cubit.state.errorMessage, 'bookingHoldFailed');
      expect(cubit.state.holdToken, isNull);
    },
  );

  test(
    'a real conflict keeps the server error and clears the selection',
    () async {
      response({'success': false, 'error_code': 'slot_overlap'});
      expect(await cubit.verifyAvailabilityBeforeProceed(), isFalse);
      expect(cubit.state.errorMessage, 'slot_overlap');
      expect(cubit.state.startTime, isNull);
      expect(cubit.state.holdToken, isNull);
    },
  );

  test(
    'an unexplained rejection is not reported as a booking conflict',
    () async {
      response({'success': false});
      expect(await cubit.verifyAvailabilityBeforeProceed(), isFalse);
      expect(cubit.state.errorMessage, 'bookingHoldFailed');
    },
  );
}
