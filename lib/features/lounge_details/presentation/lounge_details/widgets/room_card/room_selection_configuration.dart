import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../lounge_details_cubit.dart';
import '../../lounge_details_state.dart';
import 'room_play_mode_selector.dart';
import 'room_controller_selector.dart';

class RoomSelectionConfiguration extends StatelessWidget {
  final RoomModel room;
  final Color themeColor;
  const RoomSelectionConfiguration({
    super.key,
    required this.room,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) =>
            a.roomPlayModes[room.id] != b.roomPlayModes[room.id] ||
            a.roomExtraControllers[room.id] != b.roomExtraControllers[room.id],
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (room.supportsPlayModePricing)
              RoomPlayModeSelector(
                roomId: room.id,
                mode: state.roomPlayModes[room.id] ?? 'single',
                color: themeColor,
              ),
            if (room.requiresControllers && room.extraControllerPrice > 0)
              RoomControllerSelector(
                room: room,
                count: state.roomExtraControllers[room.id] ?? 0,
              ),
          ],
        ),
      );
}
