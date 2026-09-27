import 'package:equatable/equatable.dart';

import '../../../home/data/models/lounge_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../../../lounge_details/data/models/room_model.dart';
import '../../data/models/booking_model.dart';

class QuickRebookSetup extends Equatable {
  final BookingModel pastBooking;
  final LoungeModel lounge;
  final RoomModel room;
  final List<ExtraModel> availableExtras;
  final Map<String, int> selectedAddonQuantities;
  final List<String> removedAddonNames;
  final int durationMinutes;
  final String playMode;
  final int extraControllers;

  const QuickRebookSetup({
    required this.pastBooking,
    required this.lounge,
    required this.room,
    required this.availableExtras,
    required this.selectedAddonQuantities,
    required this.removedAddonNames,
    required this.durationMinutes,
    required this.playMode,
    required this.extraControllers,
  });

  @override
  List<Object?> get props => [
        pastBooking,
        lounge,
        room,
        availableExtras,
        selectedAddonQuantities,
        removedAddonNames,
        durationMinutes,
        playMode,
        extraControllers,
      ];
}
