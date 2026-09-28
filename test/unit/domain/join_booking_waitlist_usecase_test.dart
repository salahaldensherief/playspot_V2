import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/booking/domain/repositories/booking_waitlist_repository.dart';
import 'package:playspot/features/booking/domain/usecases/join_booking_waitlist_usecase.dart';

class MockBookingWaitlistRepository extends Mock
    implements BookingWaitlistRepository {}

void main() {
  final start = DateTime(2030, 1, 15, 20);
  final end = start.add(const Duration(hours: 1));

  test('retrying a successful request preserves the server request identity', () async {
    final repository = MockBookingWaitlistRepository();
    final useCase = JoinBookingWaitlistUseCase(repository);
    when(() => repository.join(roomId: 'room-1', startAt: start, endAt: end))
        .thenAnswer((_) async => const Right({
              'success': true,
              'waitlist_id': 'existing-request',
            }));

    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await useCase(
        roomId: 'room-1',
        startAt: start,
        endAt: end,
      );
      expect(result.fold((_) => null, (id) => id), 'existing-request');
    }
    verify(() => repository.join(roomId: 'room-1', startAt: start, endAt: end))
        .called(2);
  });

  test('never treats a rejected or malformed RPC response as enrollment', () async {
    final repository = MockBookingWaitlistRepository();
    final useCase = JoinBookingWaitlistUseCase(repository);
    when(() => repository.join(roomId: 'room-1', startAt: start, endAt: end))
        .thenAnswer((_) async => const Right({
              'success': false,
              'error_code': 'SLOT_AVAILABLE_NOW',
            }));

    final rejected = await useCase(roomId: 'room-1', startAt: start, endAt: end);
    expect(rejected.isLeft(), isTrue);

    when(() => repository.join(roomId: 'room-1', startAt: start, endAt: end))
        .thenAnswer((_) async => const Right({'success': true}));
    final malformed = await useCase(roomId: 'room-1', startAt: start, endAt: end);
    expect(malformed.isLeft(), isTrue);
  });
}
