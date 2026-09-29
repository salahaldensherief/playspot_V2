import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/room_slot_price.dart';
import '../repositories/booking_repository.dart';

class GetRoomSlotsWithPricesUseCase {
  final BookingRepository _repository;

  GetRoomSlotsWithPricesUseCase(this._repository);

  Future<Either<Failure, List<RoomSlotPrice>>> call({
    required String roomId,
    required String date,
  }) {
    return _repository.getRoomSlotsWithPrices(
      roomId: roomId,
      date: date,
    );
  }
}
