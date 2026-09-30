import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../entities/slot_waitlist_result.dart';

abstract class SlotWaitlistRepository {
  Future<Either<Failure, SlotWaitlistResult>> joinSlotWaitlist({
    required String loungeId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
  });
}
