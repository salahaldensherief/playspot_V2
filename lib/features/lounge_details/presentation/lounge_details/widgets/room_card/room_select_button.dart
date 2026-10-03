import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: AppButton(
      content: ButtonContent(
        label: (selected ? 'room_selected' : 'room_select').tr(),
        icon: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.add_circle_outline_rounded,
          color: selected ? AppColors.black : color,
          size: 18,
        ),
      ),
      behavior: ButtonBehavior.tap(
        onTap: () =>
            context.read<LoungeDetailsCubit>().toggleRoomSelection(roomId),
      ),
      buttonConfig: ButtonConfig(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        height: 48 * MediaQuery.textScalerOf(context).scale(1),
        borderRadius: 12,
        backgroundColor: selected ? color : color.withValues(alpha: 0.12),
        borderColor: color,
        textStyle: TextStyle(
          color: selected ? AppColors.black : color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
