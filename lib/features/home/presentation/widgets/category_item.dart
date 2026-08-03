import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class CategoryItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback? onTap;

  const CategoryItem({
    super.key,
    required this.name,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Icon(
              icon,
              color: AppColors.neonBlue,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            text: name,
            fontSize: 10.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
