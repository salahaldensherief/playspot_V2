import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../lounge_details_cubit.dart';

class RoomPlayModeSelector extends StatelessWidget {
  final String roomId;
  final String mode;
  final Color color;
  const RoomPlayModeSelector({
    super.key,
    required this.roomId,
    required this.mode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        AppStrings.playMode.tr(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _option(context, 'single', AppStrings.singlePlay.tr()),
          _option(context, 'multi', AppStrings.multiPlay.tr()),
        ],
      ),
    ],
  );

  Widget _option(BuildContext context, String value, String label) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: ChoiceChip(
          label: Text(label),
          selected: mode == value,
          selectedColor: color.withValues(alpha: 0.2),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) =>
              context.read<LoungeDetailsCubit>().setRoomPlayMode(roomId, value),
        ),
      );
}
