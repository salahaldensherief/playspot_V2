import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

class AppDivider extends StatelessWidget {
  final double? verticalPadding;
  final Color? color;

  const AppDivider({
    super.key,
    this.verticalPadding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding ?? 16.h),
      child: Divider(
        color: color ?? AppColors.borderDefault,
        thickness: 1,
      ),
    );
  }
}
