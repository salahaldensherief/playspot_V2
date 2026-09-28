import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class QuickRebookHeader extends StatelessWidget {
  final VoidCallback onClose;

  const QuickRebookHeader({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: AppColors.neonBlue,
            size: 24.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                text: AppStrings.quickRebookTitle.tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              SizedBox(height: 2.h),
              AppText(
                text: AppStrings.quickRebookSubtitle.tr(),
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white70,
            size: 20.sp,
          ),
          onPressed: onClose,
        ),
      ],
    );
  }
}
