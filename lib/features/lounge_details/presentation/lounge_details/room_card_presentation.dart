import 'package:equatable/equatable.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

import 'lounge_details_state.dart';

class RoomCardPresentation extends Equatable {
  final bool isAvailable;
  final bool isSelected;
  final String availabilityKey;
  final LoungeModel? lounge;
  const RoomCardPresentation({
    required this.isAvailable,
    required this.isSelected,
    required this.availabilityKey,
    required this.lounge,
  });

  factory RoomCardPresentation.fromState(
    RoomModel room,
    LoungeDetailsState state,
  ) {
    final operatingStatus = state.operatingStatus;
    final open =
        operatingStatus?.isOpen == true &&
        operatingStatus?.canBookOnline == true;
    final busy = state.bookedRoomIds.contains(room.id);
    final unknownAvailability =
        state.availabilityLoadFailed ||
        state.isDateLoading ||
        state.status != LoungeDetailsStatus.success;
    return RoomCardPresentation(
      isAvailable: open && !busy && !unknownAvailability,
      isSelected: state.isRoomSelected(room.id),
      lounge: state.lounge,
      availabilityKey:
          operatingStatus == null || operatingStatus.status == 'unavailable'
          ? 'operating_status_unavailable'
          : operatingStatus.isTechnicalIssue ||
                (operatingStatus.isOpen && !open)
          ? 'technical_issue'
          : !open
          ? 'room_closed'
          : unknownAvailability
          ? 'room_availability_unavailable'
          : busy
          ? 'room_busy'
          : 'room_available',
    );
  }

  bool get hasLoungeOffer =>
      (lounge?.isDiscountActive ?? false) &&
      (lounge?.discountPercentage ?? 0) > 0;
  bool hasOffer(RoomModel room) => room.hasActivePromo || hasLoungeOffer;

  @override
  List<Object?> get props => [isAvailable, isSelected, availabilityKey, lounge];
}
