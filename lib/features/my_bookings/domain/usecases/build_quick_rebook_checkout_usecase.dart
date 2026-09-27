import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../booking/data/models/booking_params.dart';
import '../../../booking/domain/repositories/booking_repository.dart';
import '../entities/quick_rebook_setup.dart';

class BuildQuickRebookCheckoutUseCase {
  final BookingRepository _bookingRepository;

  const BuildQuickRebookCheckoutUseCase(
    this._bookingRepository,
  );

  Future<Either<Failure, CheckoutParams>> call({
    required QuickRebookSetup setup,
    required DateTime selectedDate,
    required TimeOfDay selectedSlot,
    required int durationMinutes,
    required Map<String, int> selectedAddonQuantities,
  }) async {
    final startAt = _resolveOperationalDateTime(
      selectedDate,
      selectedSlot,
      setup.lounge.openingTime,
      setup.lounge.closingTime,
    );
    final endAt = startAt.add(
      Duration(minutes: durationMinutes),
    );

    final holdResult = await _bookingRepository.acquireBookingHold(
      roomIds: [setup.room.id],
      startTime: startAt,
      endTime: endAt,
    );

    return holdResult.fold(
      (failure) => Left(failure),
      (hold) {
      if (hold['success'] != true) {
        return Left(
          ServerFailure(
            hold['error_code']?.toString() ??
                'quickRebookHoldFailed',
          ),
        );
      }

      final holdToken = hold['hold_token']?.toString();
      final holdExpiresAt = DateTime.tryParse(
        hold['hold_expires_at']?.toString() ?? '',
      );

      if (holdToken == null ||
          holdToken.isEmpty ||
          holdExpiresAt == null) {
        return const Left(
          ServerFailure('quickRebookHoldFailed'),
        );
      }

      final addons = <Map<String, dynamic>>[];
      for (final entry in selectedAddonQuantities.entries) {
        final matches = setup.availableExtras.where(
          (extra) => extra.id == entry.key,
        );
        if (matches.isEmpty) continue;

        final extra = matches.first;
        addons.add({
          'id': extra.id,
          'extra_id': extra.id,
          'name': extra.name,
          'name_ar': extra.nameAr,
          'name_en': extra.nameEn,
          'quantity': entry.value,
          'unit_price': extra.price,
          'price': extra.price,
        });
      }

      return Right(
        CheckoutParams(
          lounge: setup.lounge,
          rooms: [setup.room],
          roomsBreakdown: [
            {
              'roomId': setup.room.id,
              'playMode': setup.playMode,
              'extraControllers': setup.extraControllers,
            },
          ],
          date: selectedDate,
          startTime: selectedSlot,
          duration: durationMinutes,
          originalRoomSubtotal: 0,
          discountedRoomSubtotal: 0,
          discountAmount: 0,
          discountPercentage: 0,
          addonsTotal: 0,
          totalPrice: 0,
          originalTotalPrice: 0,
          addOns: addons,
          playMode: setup.playMode,
          extraControllers: setup.extraControllers,
          extraControllerPrice: setup.room.extraControllerPrice,
          holdToken: holdToken,
          holdExpiresAt: holdExpiresAt,
          resolvedStartAt: startAt,
        ),
      );
    },
    );
  }

  DateTime _resolveOperationalDateTime(
    DateTime selectedDate,
    TimeOfDay time,
    String openingTime,
    String closingTime,
  ) {
    final openingMinutes = _parseTimeToMinutes(openingTime);
    final closingMinutes = _parseTimeToMinutes(closingTime);
    final selectedMinutes = time.hour * 60 + time.minute;

    var dayOffset = 0;
    if (openingMinutes != null &&
        closingMinutes != null &&
        closingMinutes <= openingMinutes &&
        selectedMinutes < closingMinutes) {
      dayOffset = 1;
    }

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day + dayOffset,
      time.hour,
      time.minute,
    );
  }

  int? _parseTimeToMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }
}
