import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:playspot/art_core/app_strings.dart';

class TimerWidget extends StatelessWidget {
  final Duration remaining;
  final double progress;
  final Color statusColor;
  final String? labelOverride;

  const TimerWidget({
    super.key,
    required this.remaining,
    required this.progress,
    required this.statusColor,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    final timeStr = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    final label = labelOverride ?? (remaining.isNegative 
        ? AppStrings.overtime.tr().toUpperCase() 
        : AppStrings.remaining.tr().toUpperCase());

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative glow behind indicator
          Container(
            width: 210.w,
            height: 210.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.withOpacity(statusColor, 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 220.w,
            height: 220.w,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12.w,
              backgroundColor: AppColors.mutedBackground,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                text: timeStr,
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 8.h),
              AppText(
                text: label,
                fontSize: 12.sp,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
