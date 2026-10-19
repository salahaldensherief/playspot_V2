import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenNoteField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const CanteenNoteField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          text: AppStrings.orderNoteHint.tr(),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: AppColors.neonPurple,
                size: 22.sp,
              ),
              hintText: AppStrings.orderNoteHint.tr(),
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12.5.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsetsDirectional.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
            ),
            style: TextStyle(color: Colors.white, fontSize: 13.5.sp),
          ),
        ),
      ],
    );
  }
}
