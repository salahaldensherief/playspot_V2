import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_spec.dart';

class RoomQuickSpecs extends StatelessWidget {
  final RoomModel room;
  const RoomQuickSpecs({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.w,
      children: [
        if (room.isSimulator)
          RoomSpec(
              icon: Icons.settings_input_component,
              value: room.activityNames.firstWhere(
                  (a) => a.toLowerCase().contains('fanatec'),
                  orElse: () => "Pro Racing Setup"))
        else if (room.isVR)
          RoomSpec(
              icon: Icons.headset,
              value: room.activityNames.firstWhere(
                  (a) => a.toLowerCase().contains('quest'),
                  orElse: () => "VR Experience"))
        else
          RoomSpec(
              icon: Icons.videogame_asset_outlined,
              value: "${room.controllersCount} ${AppStrings.controllers.tr()}"),
        RoomSpec(icon: Icons.tv, value: room.screenSize),
        if (!room.isOpenArea)
          RoomSpec(icon: Icons.people_outline, value: room.capacity.toString()),
      ],
    );
  }
}
