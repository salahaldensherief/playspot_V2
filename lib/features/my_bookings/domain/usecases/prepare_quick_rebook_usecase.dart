import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../../../lounge_details/domain/repositories/lounge_details_repository.dart';
import '../../data/models/booking_model.dart';
import '../entities/quick_rebook_setup.dart';

class PrepareQuickRebookUseCase {
  final HomeRepository _homeRepository;
  final LoungeDetailsRepository _loungeDetailsRepository;

  const PrepareQuickRebookUseCase(
    this._homeRepository,
    this._loungeDetailsRepository,
  );

  Future<Either<Failure, QuickRebookSetup>> call(
    BookingModel pastBooking,
  ) async {
    final loungeId = pastBooking.loungeId;
    final roomId = pastBooking.roomId;

    if (loungeId == null || loungeId.isEmpty) {
      return const Left(
        ServerFailure('quickRebookMissingLounge'),
      );
    }

    if (roomId == null || roomId.isEmpty) {
      return const Left(
        ServerFailure('quickRebookMissingRoom'),
      );
    }

    final loungeResult = await _homeRepository.getLoungeById(loungeId);
    final lounge = loungeResult.fold(
      (_) => null,
      (value) => value,
    );

    if (lounge == null) {
      return const Left(
        ServerFailure('quickRebookLoungeUnavailable'),
      );
    }

    final roomResult = await _loungeDetailsRepository.getRoomById(
      roomId,
      forceRefresh: true,
    );
    final room = roomResult.fold(
      (_) => null,
      (value) => value,
    );

    if (room == null ||
        room.loungeId != loungeId ||
        !room.isAvailable ||
        room.status.trim().toLowerCase() == 'deleted') {
      return const Left(
        ServerFailure('quickRebookRoomUnavailable'),
      );
    }

    final extrasResult = await _loungeDetailsRepository.getExtras(
      loungeId,
      forceRefresh: true,
    );
    final availableExtras = extrasResult.fold(
      (_) => const <dynamic>[],
      (value) => value,
    );

    final selectedAddonQuantities = <String, int>{};
    final removedAddonNames = <String>[];

    for (final item in pastBooking.canteenItems) {
      final extraId = (item['extra_id'] ??
              item['id'] ??
              item['product_id'])
          ?.toString();
      final name = item['name']?.toString() ?? '';
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

      if (extraId == null || extraId.isEmpty) {
        if (name.isNotEmpty) removedAddonNames.add(name);
        continue;
      }

      final matches = availableExtras.where(
        (extra) => extra.id == extraId,
      );

      if (matches.isEmpty) {
        if (name.isNotEmpty) removedAddonNames.add(name);
        continue;
      }

      selectedAddonQuantities[extraId] = quantity.clamp(1, 100);
    }

    final playMode = pastBooking.playMode == 'multi'
        ? 'multi'
        : 'single';

    return Right(
      QuickRebookSetup(
        pastBooking: pastBooking,
        lounge: lounge,
        room: room,
        availableExtras: List.unmodifiable(availableExtras),
        selectedAddonQuantities:
            Map.unmodifiable(selectedAddonQuantities),
        removedAddonNames: List.unmodifiable(removedAddonNames),
        durationMinutes: _durationMinutes(pastBooking),
        playMode: playMode,
        extraControllers:
            pastBooking.extraControllers.clamp(0, 20),
      ),
    );
  }

  int _durationMinutes(BookingModel booking) {
    final start = _parseMinutes(booking.startTime);
    final end = _parseMinutes(booking.endTime);

    if (start == null || end == null) return 60;

    var normalizedEnd = end;
    if (normalizedEnd <= start) normalizedEnd += 24 * 60;

    final duration = normalizedEnd - start;
    if (duration < 15 || duration > 24 * 60) return 60;

    return duration;
  }

  int? _parseMinutes(String raw) {
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
