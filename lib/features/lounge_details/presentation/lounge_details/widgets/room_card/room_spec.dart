import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomSpec extends StatelessWidget {
  final IconData icon;
  final String value;
  const RoomSpec({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.contains('0') && !value.contains('10')) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: AppColors.textSecondary.withOpacity(0.4)),
        SizedBox(width: 4.w),
        AppText(
            text: value,
            fontSize: 10.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500),
      ],
    );
  }
}
