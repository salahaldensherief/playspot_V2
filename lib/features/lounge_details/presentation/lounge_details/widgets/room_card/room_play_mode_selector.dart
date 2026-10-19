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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          text: AppStrings.playMode.tr(),
          fontSize: 13.sp,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppColors.mutedBackground,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildOption(
                  context,
                  'single',
                  AppStrings.singlePlay.tr(),
                ),
              ),
              Expanded(
                child: _buildOption(
                  context,
                  'multi',
                  AppStrings.multiPlay.tr(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, String value, String label) {
    final isSelected = mode == value;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: () =>
            context.read<LoungeDetailsCubit>().setRoomPlayMode(roomId, value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: AppText(
            text: label,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
