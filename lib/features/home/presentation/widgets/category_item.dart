import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/utils/extensions/spacing_extensions.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              borderRadius: AppSizes.r20.r,
              height: 75.h,
              width: 80.w,
              borderOpacity: isSelected ? 0.3 : 0.05,
              borderColor: isSelected ? AppColors.neonBlue : Colors.white.withOpacity(0.1),
              color: isSelected ? AppColors.neonBlue.withOpacity(0.08) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                    size: 26.sp,
                  ),
                  6.verticalSpace,
                  AppText(
                    text: name.toUpperCase(),
                    fontSize: 9.sp,
                    color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 0.5,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
