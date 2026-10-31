import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import '../../lounge_details_cubit.dart';
import 'room_constants.dart';

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
    button: true,
    selected: selected,
    label: (selected ? 'room_selected' : 'room_select').tr(),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.read<LoungeDetailsCubit>().toggleRoomSelection(roomId),
      child: AnimatedContainer(
        duration: RoomConstants.toggleDuration,
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          selected ? Icons.check : Icons.add,
          color: selected ? AppColors.black : Colors.white,
          size: 16.sp,
        ),
      ),
    ),
  );
}
