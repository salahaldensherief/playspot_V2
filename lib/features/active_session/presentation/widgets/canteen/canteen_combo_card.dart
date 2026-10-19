import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/images/app_images.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../domain/entities/canteen_combo.dart';
import '../../../domain/entities/out_of_stock_item.dart';
import 'canteen_qty_stepper.dart';

class CanteenComboCard extends StatelessWidget {
  final CanteenCombo combo;
  final int qty;
  final OutOfStockItem? unavailableItem;
  final bool isArabic;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const CanteenComboCard({
    super.key,
    required this.combo,
    required this.qty,
    required this.unavailableItem,
    required this.isArabic,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = combo.getName(isArabic);
    final componentsSummary = combo.items
        .map((c) => "${c.quantity}x ${c.getName(isArabic)}")
        .join(" + ");
    final hasSavings = combo.savings > 0;
    final imageUrl = combo.imageUrl;

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 12.h),
      padding: EdgeInsetsDirectional.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: unavailableItem != null
              ? AppColors.danger
              : (qty > 0
                    ? AppColors.neonPurple
                    : Colors.white.withValues(alpha: 0.08)),
          width: qty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: qty > 0
                ? AppColors.neonPurple.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: 7.w,
                  vertical: 2.5.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.warning,
                      size: 11.sp,
                    ),
                    SizedBox(width: 3.w),
                    const AppText(
                      text: "COMBO",
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
              if (hasSavings) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 7.w,
                    vertical: 2.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: AppText(
                    text:
                        "${AppStrings.saveAmount.tr(args: [combo.savings.toStringAsFixed(0)])} ${AppStrings.egpSymbol.tr()}",
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                AppImage(
                  urlImg: imageUrl,
                  width: 58.w,
                  height: 58.w,
                  fit: BoxFit.cover,
                  borderRadius: 12.r,
                ),
                SizedBox(width: 12.w),
              ] else ...[
                Container(
                  width: 58.w,
                  height: 58.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.neonPurple.withValues(alpha: 0.25),
                        AppColors.neonBlue.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.fastfood_rounded,
                    color: AppColors.neonPurple,
                    size: 26.sp,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (componentsSummary.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      AppText(
                        text: componentsSummary,
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4.h),
                  ],
                ),
              ),
              CanteenQtyStepper(
                qty: qty,
                accentColor: AppColors.neonPurple,
                onAdd: combo.isAvailable ? onAdd : null,
                onRemove: onRemove,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppText(
                text:
                    "${combo.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
              if (combo.separateItemsPrice > combo.price)
                Text(
                  "${combo.separateItemsPrice.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          if (!combo.isAvailable || unavailableItem != null) ...[
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
                text: !combo.isAvailable
                    ? AppStrings.canteenItemUnavailable.tr()
                    : AppStrings.remainingQuantity.tr(
                        args: [unavailableItem!.available.toString()],
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
