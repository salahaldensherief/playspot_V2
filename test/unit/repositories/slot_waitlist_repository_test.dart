import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/slot_waitlist/data/datasources/remote/slot_waitlist_remote_data_source.dart';
import 'package:playspot/features/slot_waitlist/data/repositories/slot_waitlist_repository_impl.dart';
import 'package:playspot/features/slot_waitlist/domain/entities/slot_waitlist_result.dart';

class MockSlotWaitlistRemoteDataSource extends Mock
    implements SlotWaitlistRemoteDataSource {}

void main() {
  late MockSlotWaitlistRemoteDataSource mockRemoteDataSource;
  late SlotWaitlistRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockSlotWaitlistRemoteDataSource();
    repository = SlotWaitlistRepositoryImpl(mockRemoteDataSource);
  });

  const loungeId = 'lounge-1';
  const roomIds = ['room-1', 'room-2'];
  final date = DateTime(2026, 10, 1);
  const slotTime = TimeOfDay(hour: 20, minute: 30);

  group('SlotWaitlistRepositoryImpl Tests', () {
    test('returns Right(SlotWaitlistResult) when remote data source succeeds', () async {
      const remoteResult = SlotWaitlistResult(
        isSuccess: true,
        isPartial: false,
        successfulRoomsCount: 2,
        failedRoomsCount: 0,
      );

      when(
        () => mockRemoteDataSource.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).thenAnswer((_) async => remoteResult);

      final result = await repository.joinSlotWaitlist(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected right'),
        (data) => expect(data, remoteResult),
      );
    });

    test('returns Left(ServerFailure) when remote data source throws exception', () async {
      when(
        () => mockRemoteDataSource.joinSlotWaitlist(
          loungeId: loungeId,
          roomIds: roomIds,
          date: date,
          slotTime: slotTime,
        ),
      ).thenThrow(Exception('Network error'));

      final result = await repository.joinSlotWaitlist(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected left'),
      );
    });
  });
}
