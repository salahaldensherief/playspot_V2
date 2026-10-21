import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:playspot/features/my_bookings/presentation/my_bookings_cubit.dart';

class _Repository extends Mock implements MyBookingsRepository {}

void main() {
  test('pending refresh after disposal does not emit or fetch again', () async {
    final repository = _Repository();
    final pending = Completer<Either<Failure, List<BookingModel>>>();
    when(() => repository.getMyBookings()).thenAnswer((_) => pending.future);
    final cubit = MyBookingsCubit(repository);
    final refresh = cubit.getMyBookings();
    await cubit.getMyBookings();
    await cubit.close();
    pending.complete(const Right([]));
    await refresh;
    verify(() => repository.getMyBookings()).called(1);
  });
  test('late cancellation failure is ignored after disposal', () async {
    final repository = _Repository();
    final pending = Completer<Either<Failure, void>>();
    when(
      () => repository.cancelBooking('booking', 'urgent'),
    ).thenAnswer((_) => pending.future);
    final cubit = MyBookingsCubit(repository);
    final cancel = cubit.cancelBooking('booking', 'urgent');
    await cubit.close();
    pending.complete(const Left(ServerFailure('fixture')));
    await cancel;
    verifyNever(() => repository.getMyBookings());
  });
}
