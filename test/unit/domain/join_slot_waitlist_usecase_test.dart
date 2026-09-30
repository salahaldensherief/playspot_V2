import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/slot_waitlist/domain/entities/slot_waitlist_result.dart';
import 'package:playspot/features/slot_waitlist/domain/repositories/slot_waitlist_repository.dart';
import 'package:playspot/features/slot_waitlist/domain/usecases/join_slot_waitlist_usecase.dart';

class MockSlotWaitlistRepository extends Mock implements SlotWaitlistRepository {}

void main() {
  late MockSlotWaitlistRepository mockRepository;
  late JoinSlotWaitlistUseCase useCase;

  setUp(() {
    mockRepository = MockSlotWaitlistRepository();
    useCase = JoinSlotWaitlistUseCase(mockRepository);
  });

  const loungeId = 'lounge-123';
  const roomIds = ['room-1', 'room-2'];
  final date = DateTime(2026, 10, 1);
  const slotTime = TimeOfDay(hour: 21, minute: 0);

  group('JoinSlotWaitlistUseCase Tests', () {
    test('returns SlotWaitlistResult when repository succeeds', () async {
      const expectedResult = SlotWaitlistResult(
        isSuccess: true,
        isPartial: false,
        successfulRoomsCount: 2,
        failedRoomsCount: 0,
      );

      when(
        () => mockRepository.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).thenAnswer((_) async => const Right(expectedResult));

      final result = await useCase(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );

      expect(result, const Right(expectedResult));
      verify(
        () => mockRepository.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).called(1);
    });

    test('returns ServerFailure when repository fails', () async {
      when(
        () => mockRepository.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('Waitlist full')));

      final result = await useCase(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );

      expect(result, const Left(ServerFailure('Waitlist full')));
    });

    test('supports partial success aggregation across roomIds', () async {
      const partialResult = SlotWaitlistResult(
        isSuccess: true,
        isPartial: true,
        successfulRoomsCount: 1,
        failedRoomsCount: 1,
        message: 'notifyMePartial',
      );

      when(
        () => mockRepository.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).thenAnswer((_) async => const Right(partialResult));

      final result = await useCase(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );

      result.fold(
        (failure) => fail('Expected success'),
        (data) {
          expect(data.isSuccess, isTrue);
          expect(data.isPartial, isTrue);
          expect(data.successfulRoomsCount, 1);
          expect(data.failedRoomsCount, 1);
        },
      );
    });
  });
}
