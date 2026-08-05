import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class CategoryItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryItem({
    super.key,
    required this.name,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.1) : AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ] : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            text: name,
            fontSize: 10.sp,
            color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
