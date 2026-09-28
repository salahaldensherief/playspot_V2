import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';

class DurationSelector extends StatelessWidget {
  const DurationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingCubit = context.read<BookingCubit>();
    final isArabic = context.locale.languageCode == 'ar';

    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.durationMinutes != current.durationMinutes ||
          previous.startTime != current.startTime ||
          previous.bookedTimeSlots != current.bookedTimeSlots,
      builder: (context, state) {
        final maxDuration = bookingCubit.getMaxAvailableDurationMinutes();
        final canIncrease = state.durationMinutes < maxDuration;
        final canDecrease = state.durationMinutes > 15;

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: !canIncrease && state.startTime != null
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : AppColors.borderDefault,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: canDecrease
                          ? AppColors.textSecondary
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                      size: 28.sp,
                    ),
                    onPressed: canDecrease ? () => bookingCubit.updateDuration(-30) : null,
                  ),
                  SizedBox(width: 20.w),
                  Column(
                    children: [
                      AppText(
                        text: state.getFormattedDuration(isArabic),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonBlue,
                      ),
                    ],
                  ),
                  SizedBox(width: 20.w),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: canIncrease
                          ? AppColors.neonBlue
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                      size: 28.sp,
                    ),
                    onPressed: canIncrease ? () => bookingCubit.updateDuration(30) : null,
                  ),
                ],
              ),
              if (!canIncrease && state.startTime != null) ...[
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 12.sp),
                    SizedBox(width: 4.w),
                    AppText(
                      text: isArabic
                          ? "أقصى مدة مجهزة حتى الحجز التالي"
                          : "Max duration reached before next booking",
                      fontSize: 10.sp,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
