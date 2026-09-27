import '../../../home/data/models/lounge_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../../../lounge_details/data/models/room_model.dart';

class QuickRebookPreparation {
  final LoungeModel lounge;
  final RoomModel room;
  final List<ExtraModel> availableExtras;
  final Map<String, int> selectedAddonQuantities;
  final List<String> removedAddonNames;
  final int durationMinutes;
  final String playMode;
  final int extraControllers;

  const QuickRebookPreparation({
    required this.lounge,
    required this.room,
    required this.availableExtras,
    required this.selectedAddonQuantities,
    required this.removedAddonNames,
    required this.durationMinutes,
    required this.playMode,
    required this.extraControllers,
  });
}
