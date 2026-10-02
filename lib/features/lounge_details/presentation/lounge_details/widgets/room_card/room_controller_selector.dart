import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../lounge_details_cubit.dart';

class RoomControllerSelector extends StatelessWidget {
  final RoomModel room;
  final int count;
  const RoomControllerSelector({
    super.key,
    required this.room,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.extraControllers.tr()),
            Text(
              '+${room.extraControllerPrice} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'room_remove_controller'.tr(),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: count > 0
                  ? () => context
                        .read<LoungeDetailsCubit>()
                        .updateRoomExtraControllers(room.id, -1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'room_add_controller'.tr(),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: count < 4
                  ? () => context
                        .read<LoungeDetailsCubit>()
                        .updateRoomExtraControllers(room.id, 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );
}
