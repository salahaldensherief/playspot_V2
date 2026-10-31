import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenStockWarning extends StatelessWidget {
  const CanteenStockWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsetsDirectional.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: AppText(
                text: AppStrings.outOfStockError.tr(),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
