import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/models/time_range.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/booking/domain/strategies/booking_slot_strategy.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/domain/usecases/get_quick_rebook_slots_usecase.dart';

class MockBookingRepository extends Mock implements BookingRepository {}

class MockBookingSlotStrategy extends Mock implements BookingSlotStrategy {}

void main() {
  group('Quick Rebook canonical contracts', () {
    test('BookingModel reads booked extra controllers separately from room controllers', () {
      final booking = BookingModel.fromJson({
        'id': 'booking-1',
        'lounge_id': 'lounge-1',
        'room_id': 'room-1',
        'date': '2030-01-15',
        'start_time': '18:00:00',
        'end_time': '19:00:00',
        'status': 'completed',
        'payment_status': 'paid',
        'total_price': 150,
        'play_mode': 'multi',
        'extra_controllers': 2,
        'rooms': {
          'id': 'room-1',
          'name_en': 'VIP 1',
          'controllers_count': 4,
          'screen_size': '55"',
        },
        'lounges': {
          'id': 'lounge-1',
          'name': 'Test Lounge',
          'location': 'Cairo',
        },
      });

      expect(booking.controllersCount, 4);
      expect(booking.extraControllers, 2);
    });

    test('slot is rejected when requested duration overlaps a later booking', () async {
      final repository = MockBookingRepository();
      final strategy = MockBookingSlotStrategy();
      final useCase = GetQuickRebookSlotsUseCase(repository, strategy);

      final date = DateTime(2030, 1, 15);
      final row = <String, dynamic>{
        'room_id': 'room-1',
        'start_at': '18:30:00',
        'end_at': '19:00:00',
        'status': 'upcoming',
      };

      when(
        () => repository.getRoomBookingsForDate(
          'lounge-1',
          date,
          roomId: 'room-1',
        ),
      ).thenAnswer((_) async => Right([row]));

      when(
        () => strategy.parseBookingRow(row, date),
      ).thenReturn(
        TimeRange(
          start: DateTime(2030, 1, 15, 18, 30),
          end: DateTime(2030, 1, 15, 19),
        ),
      );

      final result = await useCase(
        loungeId: 'lounge-1',
        roomId: 'room-1',
        date: date,
        openingTime: '18:00:00',
        closingTime: '22:00:00',
        durationMinutes: 60,
      );

      result.fold(
        (failure) => fail(failure.message),
        (slots) {
          expect(
            slots.contains(const TimeOfDay(hour: 18, minute: 0)),
            isFalse,
          );
          expect(
            slots.contains(const TimeOfDay(hour: 19, minute: 0)),
            isTrue,
          );
        },
      );
    });
  });
}
