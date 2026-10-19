import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: AppText(
            text: AppStrings.playMode.tr(),
            fontSize: 12.sp,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              _buildOption(
                context,
                'single',
                "👤 ${AppStrings.singlePlay.tr()}",
              ),
              _buildOption(context, 'multi', "👥 ${AppStrings.multiPlay.tr()}"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, String value, String label) {
    final isSelected = mode == value;
    return GestureDetector(
      onTap: () =>
          context.read<LoungeDetailsCubit>().setRoomPlayMode(roomId, value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: AppText(
          text: label,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppColors.black : AppColors.textSecondary,
        ),
      ),
    );
  }
}
