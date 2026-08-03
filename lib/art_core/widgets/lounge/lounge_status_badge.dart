import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';

class LoungeStatusBadge extends StatelessWidget {
  final bool isOpen;
  const LoungeStatusBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.roomBooked;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
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
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          AppText(
            text: isOpen ? "ACTIVE" : "CLOSED",
            fontSize: 9.sp,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}
