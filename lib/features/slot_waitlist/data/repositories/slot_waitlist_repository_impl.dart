import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/slot_waitlist_result.dart';
import '../../domain/repositories/slot_waitlist_repository.dart';
import '../datasources/remote/slot_waitlist_remote_data_source.dart';

class SlotWaitlistRepositoryImpl implements SlotWaitlistRepository {
  final SlotWaitlistRemoteDataSource _remoteDataSource;

  const SlotWaitlistRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, SlotWaitlistResult>> joinSlotWaitlist({
    required String loungeId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
  }) async {
    try {
      final result = await _remoteDataSource.joinSlotWaitlist(
        loungeId: loungeId,
        roomIds: roomIds,
        date: date,
        slotTime: slotTime,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
