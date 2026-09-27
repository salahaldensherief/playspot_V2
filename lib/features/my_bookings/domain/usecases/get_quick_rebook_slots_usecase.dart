import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../art_core/models/time_range.dart';
import '../../../../core/error/failures.dart';
import '../../../booking/domain/repositories/booking_repository.dart';
import '../../../booking/domain/strategies/booking_slot_strategy.dart';

class GetQuickRebookSlotsUseCase {
  final BookingRepository _bookingRepository;
  final BookingSlotStrategy _slotStrategy;

  const GetQuickRebookSlotsUseCase(
    this._bookingRepository,
    this._slotStrategy,
  );

  Future<Either<Failure, List<TimeOfDay>>> call({
    required String loungeId,
    required String roomId,
    required DateTime date,
    required String openingTime,
    required String closingTime,
    required int durationMinutes,
  }) async {
    final openingMinutes = _parseTimeToMinutes(openingTime);
    final closingMinutes = _parseTimeToMinutes(closingTime);

    if (openingMinutes == null || closingMinutes == null) {
      return const Left(
        ServerFailure('Lounge operating hours are unavailable.'),
      );
    }

    final bookingsResult = await _bookingRepository.getRoomBookingsForDate(
      loungeId,
      date,
      roomId: roomId,
    );

    return bookingsResult.map((rawBookings) {
      final ranges = rawBookings
          .where((row) => row['room_id']?.toString() == roomId)
          .map((row) => _slotStrategy.parseBookingRow(row, date))
          .whereType<TimeRange>()
          .toList();

      final openHour = openingMinutes ~/ 60;
      final openMinute = openingMinutes % 60;
      final closeHour = closingMinutes ~/ 60;
      final closeMinute = closingMinutes % 60;

      final operationalStart = DateTime(
        date.year,
        date.month,
        date.day,
        openHour,
        openMinute,
      );

      var operationalEnd = DateTime(
        date.year,
        date.month,
        date.day,
        closeHour,
        closeMinute,
      );

      if (!operationalEnd.isAfter(operationalStart)) {
        operationalEnd = operationalEnd.add(const Duration(days: 1));
      }

      final now = DateTime.now();
      final results = <TimeOfDay>[];
      var cursor = operationalStart;

      while (!cursor.add(Duration(minutes: durationMinutes)).isAfter(
        operationalEnd,
      )) {
        final candidateEnd = cursor.add(
          Duration(minutes: durationMinutes),
        );

        final isTooSoon = cursor.isBefore(
          now.add(const Duration(minutes: 10)),
        );

        final isConflict = ranges.any(
          (range) =>
              range.start.isBefore(candidateEnd) &&
              range.end.isAfter(cursor),
        );

        if (!isTooSoon && !isConflict) {
          results.add(
            TimeOfDay(
              hour: cursor.hour,
              minute: cursor.minute,
            ),
          );
        }

        cursor = cursor.add(const Duration(minutes: 30));
      }

      return results;
    });
  }

  int? _parseTimeToMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }
}
