import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/images/app_images.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../../lounge_details/data/models/extra_model.dart';
import '../../../domain/entities/out_of_stock_item.dart';
import 'canteen_qty_stepper.dart';

class CanteenExtraCard extends StatelessWidget {
  final ExtraModel item;
  final int qty;
  final OutOfStockItem? unavailableItem;
  final bool isArabic;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const CanteenExtraCard({
    super.key,
    required this.item,
    required this.qty,
    required this.unavailableItem,
    required this.isArabic,
    required this.onAdd,
    required this.onRemove,
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

  @override
  Widget build(BuildContext context) {
    final displayName = isArabic
        ? (item.nameAr.isNotEmpty ? item.nameAr : item.name)
        : (item.nameEn.isNotEmpty ? item.nameEn : item.name);
    final icon = item.icon?.trim();
    final stockIssue = unavailableItem;

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 10.h),
      padding: EdgeInsetsDirectional.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: unavailableItem != null
              ? AppColors.danger
              : (qty > 0
                    ? AppColors.neonBlue
                    : Colors.white.withValues(alpha: 0.06)),
          width: qty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: qty > 0
                ? AppColors.neonBlue.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null && icon.isNotEmpty) ...[
                AppImage(
                  urlImg: icon,
                  width: 48.w,
                  height: 48.w,
                  fit: BoxFit.cover,
                  borderRadius: 12.r,
                ),
                SizedBox(width: 12.w),
              ] else ...[
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.neonBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.category),
                    color: AppColors.neonBlue,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: displayName,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                  ],
                ),
              ),
              CanteenQtyStepper(
                qty: qty,
                accentColor: AppColors.neonBlue,
                onAdd:
                    item.isAvailable &&
                        (stockIssue == null || qty < stockIssue.available)
                    ? onAdd
                    : null,
                onRemove: onRemove,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppText(
                text:
                    "${item.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
              if (item.category.isNotEmpty)
                Container(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 5.w,
                    vertical: 1.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: AppText(
                    text: _getTranslatedCategory(item.category),
                    fontSize: 9.5.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (!item.isAvailable || unavailableItem != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 8.w,
                vertical: 3.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: AppText(
                text: !item.isAvailable || stockIssue == null
                    ? AppStrings.canteenItemUnavailable.tr()
                    : AppStrings.remainingQuantity.tr(
                        args: [stockIssue.available.toString()],
                      ),
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
