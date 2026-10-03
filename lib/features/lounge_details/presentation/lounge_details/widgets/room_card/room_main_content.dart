import 'package:flutter/material.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../room_card_presentation.dart';
import 'room_action_area.dart';
import 'room_card_overview.dart';
import 'room_theme_extension.dart';

class RoomMainContent extends StatelessWidget {
  final RoomModel room;
  final RoomCardPresentation data;
  final bool expanded;
  const RoomMainContent({
    super.key,
    required this.room,
    required this.data,
    required this.expanded,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final overview = RoomCardOverview(
        room: room,
        data: data,
        expanded: expanded,
      );
      final actions = RoomActionArea(
        room: room,
        isAvailable: data.isAvailable,
        isSelected: data.isSelected,
        themeColor: room.themeColor,
      );
      // Restore the compact side-by-side card. Large text uses the full width
      // so room specifications and the booking action remain readable.
      if (constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: overview),
            SizedBox(width: 128, child: actions),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          overview,
          Divider(height: 1, color: room.themeColor.withValues(alpha: 0.16)),
          actions,
        ],
      );
    },
  );
}
