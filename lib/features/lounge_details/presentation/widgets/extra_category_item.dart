import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../data/extra_model.dart';
import 'extra_row.dart';

class ExtraCategoryItem extends StatefulWidget {
  final String category;
  final List<ExtraModel> items;

  const ExtraCategoryItem({super.key, required this.category, required this.items});

  @override
  State<ExtraCategoryItem> createState() => _ExtraCategoryItemState();
}

class _ExtraCategoryItemState extends State<ExtraCategoryItem> {
  bool isExpanded = false;

  String get translatedCategory {
    switch (widget.category.toLowerCase()) {
      case "drinks":
        return AppStrings.drinks.tr();
      case "food":
        return AppStrings.food.tr();
      case "snacks":
        return AppStrings.snacks.tr();
      default:
        return widget.category.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isExpanded ? AppColors.neonPurple : AppColors.borderDefault),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: () => setState(() => isExpanded = !isExpanded),
              leading: Icon(
                widget.category == "Drinks" ? Icons.local_drink : Icons.fastfood,
                color: AppColors.white,
              ),
              title: AppText(
                text: translatedCategory,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              trailing: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
            ),
            if (isExpanded)
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: widget.items.map((extra) => ExtraRow(extra: extra)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
