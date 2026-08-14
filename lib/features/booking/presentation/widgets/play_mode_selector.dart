import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class PlayModeSelector extends StatelessWidget {
  const PlayModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) => previous.playMode != current.playMode,
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  context,
                  label: AppStrings.singlePlay.tr(),
                  icon: Icons.person_outline,
                  isSelected: state.playMode == PlayMode.single,
                  onTap: () => context.read<BookingCubit>().selectPlayMode(PlayMode.single),
                ),
              ),
              8.horizontalSpace,
              Expanded(
                child: _buildModeOption(
                  context,
                  label: AppStrings.multiPlay.tr(),
                  icon: Icons.people_outline,
                  isSelected: state.playMode == PlayMode.multi,
                  onTap: () => context.read<BookingCubit>().selectPlayMode(PlayMode.multi),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            ),
            8.horizontalSpace,
            AppText(
              text: label,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
