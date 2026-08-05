import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';

class LoungeStatusBadge extends StatelessWidget {
  final bool isOpen;
  const LoungeStatusBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.roomBooked;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.w,
            height: 4.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          SizedBox(width: 4.w),
          AppText(
            text: (isOpen ? AppStrings.active.tr() : AppStrings.closed.tr()).toUpperCase(),
            fontSize: 8.sp,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}
