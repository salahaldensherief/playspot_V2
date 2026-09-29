import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/my_bookings/domain/entities/booking_timeline_item.dart';
import 'package:playspot/features/my_bookings/domain/usecases/get_booking_timeline_usecase.dart';
import 'package:playspot/features/my_bookings/presentation/booking_timeline_cubit.dart';
import 'package:playspot/features/my_bookings/presentation/booking_timeline_state.dart';

class MockGetBookingTimelineUseCase extends Mock implements GetBookingTimelineUseCase {}

void main() {
  late MockGetBookingTimelineUseCase mockUseCase;
  late BookingTimelineCubit cubit;

  setUp(() {
    mockUseCase = MockGetBookingTimelineUseCase();
    cubit = BookingTimelineCubit(mockUseCase);
  });

  tearDown(() {
    cubit.close();
  });

  group('BookingTimelineCubit Unit Tests', () {
    final now = DateTime.now();
    final item1 = BookingTimelineItem(
      id: 'evt_1',
      eventCode: 'booking_created',
      titleAr: 'تم الحجز',
      titleEn: 'Booking Placed',
      occurredAt: now,
    );
    final item2 = BookingTimelineItem(
      id: 'evt_2',
      eventCode: 'booking_approved',
      titleAr: 'تمت الموافقة',
      titleEn: 'Approved',
      occurredAt: now,
    );
    // Duplicate item1 with same id
    final item1Duplicate = BookingTimelineItem(
      id: 'evt_1',
      eventCode: 'booking_created',
      titleAr: 'تم الحجز مكرر',
      titleEn: 'Duplicate Placed',
      occurredAt: now,
    );

    test('initial state has RequestStatus.initial and empty items', () {
      expect(cubit.state.status, RequestStatus.initial);
      expect(cubit.state.items, isEmpty);
    });

    test('fetchTimeline success filters out duplicate IDs and emits RequestStatus.success', () async {
      when(() => mockUseCase('booking-123')).thenAnswer(
        (_) async => Right([item1, item2, item1Duplicate]),
      );

      await cubit.fetchTimeline('booking-123', isArabic: true);

      expect(cubit.state.status, RequestStatus.success);
      expect(cubit.state.items.length, 2);
      expect(cubit.state.items, [item1, item2]);
      expect(cubit.state.errorMessage, null);
    });

    test('fetchTimeline failure emits RequestStatus.failure with localized error message', () async {
      when(() => mockUseCase('booking-999')).thenAnswer(
        (_) async => const Left(ServerFailure('permission denied')),
      );

      await cubit.fetchTimeline('booking-999', isArabic: true);

      expect(cubit.state.status, RequestStatus.failure);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.errorMessage, contains('صلاحية'));
    });
  });
}
