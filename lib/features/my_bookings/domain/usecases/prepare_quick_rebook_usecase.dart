import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../../../lounge_details/domain/repositories/lounge_details_repository.dart';
import '../../data/models/booking_model.dart';
import '../entities/quick_rebook_preparation.dart';

class PrepareQuickRebookUseCase {
  final HomeRepository _homeRepository;
  final LoungeDetailsRepository _loungeDetailsRepository;

  const PrepareQuickRebookUseCase(
    this._homeRepository,
    this._loungeDetailsRepository,
  );

  Future<Either<Failure, QuickRebookPreparation>> call(
    BookingModel booking,
  ) async {
    final loungeId = booking.loungeId;
    final roomId = booking.roomId;

    if (loungeId == null || loungeId.isEmpty) {
      return const Left(
        ServerFailure('Lounge identifier missing in booking record.'),
      );
    }

    if (roomId == null || roomId.isEmpty) {
      return const Left(
        ServerFailure('Room identifier missing in booking record.'),
      );
    }

    final loungeResult = await _homeRepository.getLoungeById(
      loungeId,
      forceRefresh: true,
    );

    return await loungeResult.fold(
      (failure) async => Left(failure),
      (lounge) async {
        if (lounge == null || !lounge.isActive) {
          return const Left(
            ServerFailure('Lounge is no longer active or available.'),
          );
        }

        final roomResult = await _loungeDetailsRepository.getRoomById(
          roomId,
          forceRefresh: true,
        );

        return await roomResult.fold(
          (failure) async => Left(failure),
          (room) async {
            if (room == null ||
                room.loungeId != loungeId ||
                !room.isAvailable ||
                room.status.trim().toLowerCase() == 'deleted') {
              return const Left(
                ServerFailure('The original room is no longer available.'),
              );
            }

            final extrasResult = await _loungeDetailsRepository.getExtras(
              loungeId,
              forceRefresh: true,
            );

            final extras = extrasResult.fold(
              (_) => const <dynamic>[],
              (items) => items,
            );

            final selectedAddonQuantities = <String, int>{};
            final removedAddonNames = <String>[];

            for (final item in booking.canteenItems) {
              final extraId = item['extra_id']?.toString() ??
                  item['id']?.toString() ??
                  '';
              final name = item['name']?.toString() ?? '';
              final quantity =
                  (item['quantity'] as num?)?.toInt() ?? 1;

              if (extraId.isEmpty) {
                if (name.isNotEmpty) removedAddonNames.add(name);
                continue;
              }

              final matches = extras.where((extra) => extra.id == extraId);
              if (matches.isEmpty) {
                if (name.isNotEmpty) removedAddonNames.add(name);
                continue;
              }

              selectedAddonQuantities[extraId] = quantity.clamp(1, 100);
            }

            return Right(
              QuickRebookPreparation(
                lounge: lounge,
                room: room,
                availableExtras: extras.cast(),
                selectedAddonQuantities: selectedAddonQuantities,
                removedAddonNames: removedAddonNames,
                durationMinutes: _deriveDurationMinutes(booking),
                playMode: booking.playMode == 'multi' ? 'multi' : 'single',
                extraControllers: booking.extraControllers.clamp(0, 4),
              ),
            );
          },
        );
      },
    );
  }

  int _deriveDurationMinutes(BookingModel booking) {
    final startParts = booking.startTime.split(':');
    final endParts = booking.endTime.split(':');

    if (startParts.length < 2 || endParts.length < 2) {
      return 60;
    }

    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);

    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return 60;
    }

    final startTotal = startHour * 60 + startMinute;
    var endTotal = endHour * 60 + endMinute;

    if (endTotal <= startTotal) {
      endTotal += 24 * 60;
    }

    final duration = endTotal - startTotal;
    return duration >= 15 ? duration.clamp(15, 720) : 60;
  }
}
