import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';

class LoungeCategoryIcon extends StatelessWidget {
  final IconData icon;
  
  const LoungeCategoryIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: AppSizes.w4),
      child: Container(
        padding: EdgeInsets.all(AppSizes.w4 / 1.3), // Approx 3.w
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(AppSizes.r4),
        ),
        child: Icon(icon, size: 12.sp, color: AppColors.textSecondary),
      ),
    );
  }
}
