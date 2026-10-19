import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenCategoryBar extends StatelessWidget {
  final String selectedCategory;
  final bool hasCombos;
  final Set<String> categories;
  final ValueChanged<String> onSelectCategory;

  const CanteenCategoryBar({
    super.key,
    required this.selectedCategory,
    required this.hasCombos,
    required this.categories,
    required this.onSelectCategory,
  });

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'drinks':
        return Icons.local_drink_rounded;
      case 'food':
        return Icons.fastfood_rounded;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'desserts':
        return Icons.icecream_outlined;
      default:
        return Icons.restaurant_rounded;
    }
  }

  String _getTranslatedCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'drinks':
        return AppStrings.drinks.tr();
      case 'food':
        return AppStrings.food.tr();
      case 'snacks':
        return AppStrings.snacks.tr();
      default:
        return cat;
    }
  }

  Widget _buildPill({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? AppColors.neonBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => onSelectCategory(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: BoxConstraints(minHeight: 48.h),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: 14.w,
            vertical: 8.h,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      activeColor.withValues(alpha: 0.35),
                      activeColor.withValues(alpha: 0.15),
                    ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF141724),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
              SizedBox(width: 6.w),
              AppText(
                text: label,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
        children: [
          _buildPill(
            id: 'all',
            label: AppStrings.all.tr(),
            icon: Icons.grid_view_rounded,
            isSelected: selectedCategory == 'all',
          ),
          if (hasCombos) ...[
            SizedBox(width: 8.w),
            _buildPill(
              id: 'combos',
              label: AppStrings.combosAndOffers.tr(),
              icon: Icons.local_fire_department_rounded,
              isSelected: selectedCategory == 'combos',
              accentColor: AppColors.warning,
            ),
          ],
          ...categories.map((cat) {
            return Padding(
              padding: EdgeInsetsDirectional.only(start: 8.w),
              child: _buildPill(
                id: cat,
                label: _getTranslatedCategory(cat),
                icon: _getCategoryIcon(cat),
                isSelected: selectedCategory == cat,
              ),
            );
          }),
        ],
      ),
    );
  }
}
