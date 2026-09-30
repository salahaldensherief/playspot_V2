import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../entities/slot_waitlist_result.dart';
import '../repositories/slot_waitlist_repository.dart';

class JoinSlotWaitlistUseCase {
  final SlotWaitlistRepository _repository;

  const JoinSlotWaitlistUseCase(this._repository);

  Future<Either<Failure, SlotWaitlistResult>> call({
    required String loungeId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
  }) {
    return _repository.joinSlotWaitlist(
      loungeId: loungeId,
      roomIds: roomIds,
      date: date,
      slotTime: slotTime,
    );
  }
}
