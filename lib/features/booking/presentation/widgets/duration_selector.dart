import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class DurationSelector extends StatelessWidget {
  const DurationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) => previous.durationMinutes != current.durationMinutes,
      builder: (context, state) {
        final hours = state.durationMinutes / 60.0;
        final durationText = hours >= 1 
            ? AppStrings.hour_plural.tr(args: [hours.toStringAsFixed(hours == hours.toInt() ? 0 : 1)])
            : "30 ${"min30".tr().replaceAll('+ ', '')}";

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 28.sp),
                onPressed: () => context.read<BookingCubit>().updateDuration(-30),
              ),
              SizedBox(width: 24.w),
              Column(
                children: [
                  AppText(
                    text: durationText,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonBlue,
                  ),
                ],
              ),
              SizedBox(width: 24.w),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppColors.neonBlue, size: 28.sp),
                onPressed: () => context.read<BookingCubit>().updateDuration(30),
              ),
            ],
          ),
        );
      },
    );
  }
}
