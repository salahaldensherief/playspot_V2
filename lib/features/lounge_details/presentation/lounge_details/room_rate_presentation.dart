import 'package:equatable/equatable.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'lounge_details_state.dart';

class RoomRatePresentation extends Equatable {
  final double effective;
  final double original;
  const RoomRatePresentation({required this.effective, required this.original});
  bool get hasOffer => effective < original;

  factory RoomRatePresentation.fromState(
    RoomModel room,
    LoungeDetailsState state,
  ) {
    final lounge = state.lounge;
    final discount = lounge != null && lounge.isDiscountActive
        ? lounge.discountPercentage.toDouble()
        : 0.0;
    final mode = state.roomPlayModes[room.id] ?? 'single';
    final extra = state.roomExtraControllers[room.id] ?? 0;
    return RoomRatePresentation(
      effective: room.calculateEffectiveRate(
        playMode: mode,
        extraControllers: extra,
        loungeDiscountPercentage: discount,
      ),
      original: room.calculateOriginalRate(
        playMode: mode,
        extraControllers: extra,
      ),
    );
  }

  @override
  List<Object> get props => [effective, original];
}
