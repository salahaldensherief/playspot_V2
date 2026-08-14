import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final double? fontSize;
  final IconData? prefixIcon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.fontSize,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 16.sp, color: labelColor ?? AppColors.textSecondary),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: AppText(
                    text: label,
                    fontSize: fontSize ?? 14.sp,
                    color: labelColor ?? AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          AppText(
            text: value,
            fontSize: fontSize ?? 14.sp,
            color: valueColor ?? AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
