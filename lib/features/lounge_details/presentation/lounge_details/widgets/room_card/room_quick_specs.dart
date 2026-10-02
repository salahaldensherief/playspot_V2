import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_spec.dart';

class RoomQuickSpecs extends StatelessWidget {
  final RoomModel room;
  const RoomQuickSpecs({super.key, required this.room});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      if (room.controllersCount > 0)
        RoomSpec(
          icon: Icons.videogame_asset_outlined,
          value: '${room.controllersCount} ${AppStrings.controllers.tr()}',
        ),
      if (room.screenSize.trim().isNotEmpty)
        RoomSpec(icon: Icons.tv, value: room.screenSize),
      if (room.maxCapacity > 0)
        RoomSpec(
          icon: Icons.people_outline,
          value: 'room_capacity'.tr(
            namedArgs: {'count': '${room.maxCapacity}'},
          ),
        ),
    ],
  );
}
