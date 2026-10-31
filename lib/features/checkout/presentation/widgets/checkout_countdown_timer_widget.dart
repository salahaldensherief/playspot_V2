import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';

class CheckoutCountdownTimerWidget extends StatelessWidget {
  const CheckoutCountdownTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.remainingSeconds != current.remainingSeconds ||
          previous.isHoldExpired != current.isHoldExpired,
      builder: (context, state) {
        final isExpired = state.isHoldExpired;
        final timerColor = isExpired ? AppColors.danger : AppColors.warning;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: timerColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: timerColor.withValues(alpha: 0.35),
              width: 1.w,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpired ? TablerIcons.alert_triangle : TablerIcons.clock,
                color: timerColor,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: isExpired
                          ? AppStrings.bookingHoldExpired.tr()
                          : AppStrings.bookingHoldTimer.tr(),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                    ),
                    SizedBox(height: 2.h),
                    AppText(
                      text: isExpired
                          ? AppStrings.bookingHoldExpiredHint.tr()
                          : AppStrings.bookingHoldTimerHint.tr(),
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (!isExpired)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: timerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: timerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: AppText(
                    text: state.formattedRemainingTime,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                      border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.danger),
                      ),
                    ),
                    child: AppText(
                      text: AppStrings.reselectTime.tr(),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
