import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenQtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final Color accentColor;

  const CanteenQtyStepper({
    super.key,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    this.accentColor = AppColors.neonBlue,
  });

  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.r),
          onTap: onAdd,
          child: Container(
            constraints: BoxConstraints(minHeight: 48.h, minWidth: 48.w),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: 14.w,
              vertical: 8.h,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16.sp, color: Colors.white),
                SizedBox(width: 4.w),
                AppText(
                  text: AppStrings.addSuggestion.tr(),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(minHeight: 48.h),
      padding: EdgeInsetsDirectional.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2032),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: onRemove,
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Center(
                  child: Icon(
                    Icons.remove_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 10.w),
            child: AppText(
              text: '$qty',
              fontSize: 14.5.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: onAdd,
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
