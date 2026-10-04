import 'package:equatable/equatable.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_details_state.dart';

class LoungeBookingSelection extends Equatable {
  final LoungeDetailsState state;
  final LoungeModel lounge;
  const LoungeBookingSelection(this.state, this.lounge);

  bool get isEnabled {
    final opStatus = state.operatingStatus;
    // A cached lounge flag is not an online-booking authorization.
    final canBook = opStatus?.canBookOnline == true && opStatus?.isOpen == true;
    return canBook &&
        !state.isDateLoading &&
        state.status == LoungeDetailsStatus.success &&
        state.selectedRooms.isNotEmpty &&
        state.selectedRooms.every(
          (room) =>
              room.isAvailable &&
              !room.isOccupied &&
              !state.bookedRoomIds.contains(room.id),
        );
  }

  BookingDetailsParams? get params {
    if (!isEnabled) return null;
    final room = state.selectedRooms.first;
    return BookingDetailsParams(
      lounge: lounge,
      rooms: state.selectedRooms,
      selectedDate: state.selectedDate ?? DateTime.now(),
      extras: _extras(),
      playMode:
          state.roomPlayModes[room.id] ??
          (room.isOpenArea ? 'single' : 'multi'),
      extraControllers: state.roomExtraControllers[room.id] ?? 0,
      roomPlayModes: Map.of(state.roomPlayModes),
      roomExtraControllers: Map.of(state.roomExtraControllers),
    );
  }

  List<Map<String, dynamic>> _extras() => [
    for (final extra in state.extras)
      if ((state.selectedExtras[extra.id] ?? 0) > 0)
        {
          'id': extra.id,
          'name': extra.name,
          'price': extra.price,
          'quantity': state.selectedExtras[extra.id],
        },
  ];

  @override
  List<Object> get props => [state, lounge];
}
