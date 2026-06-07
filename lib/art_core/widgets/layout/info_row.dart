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

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(
            text: label,
            fontSize: fontSize ?? 14.sp,
            color: labelColor ?? AppColors.textSecondary,
          ),
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
