import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

import '../../lounge_details_cubit.dart';

class RoomSelectButton extends StatelessWidget {
  final String roomId;
  final bool selected;
  final Color color;
  const RoomSelectButton({
    super.key,
    required this.roomId,
    required this.selected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    showCheckmark: false,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    avatar: Icon(
      selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
      color: selected ? AppColors.black : color,
      size: 15,
    ),
    label: Text((selected ? 'room_selected' : 'room_select').tr()),
    labelStyle: TextStyle(
      color: selected ? AppColors.black : color,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    backgroundColor: color.withValues(alpha: 0.10),
    selectedColor: color,
    side: BorderSide(color: color.withValues(alpha: 0.6)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    onSelected: (_) =>
        context.read<LoungeDetailsCubit>().toggleRoomSelection(roomId),
  );
}
