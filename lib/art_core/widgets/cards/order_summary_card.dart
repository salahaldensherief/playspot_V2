import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/dashed_divider.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class OrderItemData {
  final String name;
  final int quantity;
  final double price;
  final IconData? icon;

  const OrderItemData({
    required this.name,
    required this.quantity,
    required this.price,
    this.icon,
  });
}

class DiscountData {
  final String label;
  final double amount;

  const DiscountData({
    required this.label,
    required this.amount,
  });
}

class OrderSummaryCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? statusText;
  final Color? statusColor;
  
  // Session / Base cost breakdown
  final String baseCostLabel;
  final double baseCostAmount;
  final List<Map<String, dynamic>> sessionDetailsRows;
  
  // Canteen / Add-ons items
  final List<OrderItemData> canteenItems;
  
  // Discounts & Vouchers
  final List<DiscountData> discounts;
  
  final double grandTotal;
  final String? currencySymbol;

  const OrderSummaryCard({
    super.key,
    required this.title,
    this.subtitle,
    this.statusText,
    this.statusColor,
    required this.baseCostLabel,
    required this.baseCostAmount,
    this.sessionDetailsRows = const [],
    this.canteenItems = const [],
    this.discounts = const [],
    required this.grandTotal,
    this.currencySymbol,
  });

  @override
  State<OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<OrderSummaryCard> {
  bool _isCanteenExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool isArabic = false;
    try {
      isArabic = context.locale.languageCode == 'ar';
    } catch (_) {
      try {
        isArabic = Localizations.localeOf(context).languageCode == 'ar';
      } catch (_) {}
    }

    String currency = widget.currencySymbol ?? 'EGP';
    try {
      currency = widget.currencySymbol ?? AppStrings.egp.tr();
    } catch (_) {}

    final maxVisibleCanteenItems = 3;
    final hasMoreCanteen = widget.canteenItems.length > maxVisibleCanteenItems;
    final displayedCanteenItems = (_isCanteenExpanded || !hasMoreCanteen)
        ? widget.canteenItems
        : widget.canteenItems.take(maxVisibleCanteenItems).toList();

    final canteenSubtotal = widget.canteenItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.black, 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section with Title & Status Badge
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text: widget.title,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      if (widget.subtitle != null) ...[
                        SizedBox(height: 3.h),
                        AppText(
                          text: widget.subtitle!,
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.statusText != null) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: (widget.statusColor ?? AppColors.success).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: (widget.statusColor ?? AppColors.success).withValues(alpha: 0.4),
                      ),
                    ),
                    child: AppText(
                      text: widget.statusText!,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.statusColor ?? AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: const DashedDivider(),
          ),

          // 2. Session / Room Section (Tile breakdown)
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.videogame_asset_rounded,
                      size: 16.sp,
                      color: AppColors.neonBlue,
                    ),
                    SizedBox(width: 8.w),
                    AppText(
                      text: AppStrings.sessionDetails.tr(),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Base Cost Row
                SizedBox(
                  height: 34.h,
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          text: widget.baseCostLabel,
                          fontSize: 13.5.sp,
                          color: Colors.white.withValues(alpha: 0.9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AppText(
                        text: "${widget.baseCostAmount.toStringAsFixed(2)} $currency",
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                // Additional session info rows (~36px height)
                for (var row in widget.sessionDetailsRows)
                  SizedBox(
                    height: 34.h,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText(
                            text: row['label']?.toString() ?? '',
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          text: row['value']?.toString() ?? '',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: row['color'] ?? Colors.white,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 3. Canteen / Add-ons Section (if any)
          if (widget.canteenItems.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: const DashedDivider(),
            ),
            Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.fastfood_outlined,
                              size: 16.sp,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: AppText(
                                text: isArabic ? "الكانتين والأصناف الإضافية" : "Canteen & Items",
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AppText(
                        text: "${canteenSubtotal.toStringAsFixed(2)} $currency",
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  // Canteen item rows (approx 36px height each, with quantity chip before item name)
                  for (var item in displayedCanteenItems)
                    SizedBox(
                      height: 36.h,
                      child: Row(
                        children: [
                          // Quantity Chip before item name (solves Arabic RTL text direction & rapid scanning)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: AppColors.neonBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: AppText(
                              text: "${item.quantity}×",
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonBlue,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: AppText(
                              text: item.name,
                              fontSize: 13.sp,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          AppText(
                            text: "${(item.price * item.quantity).toStringAsFixed(2)} $currency",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  if (hasMoreCanteen) ...[
                    SizedBox(height: 6.h),
                    GestureDetector(
                      onTap: () => setState(() => _isCanteenExpanded = !_isCanteenExpanded),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppText(
                              text: _isCanteenExpanded
                                  ? (isArabic ? "عرض أقل" : "Show less")
                                  : "+${widget.canteenItems.length - maxVisibleCanteenItems} ${isArabic ? "أصناف أخرى" : "more items"}...",
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonBlue,
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              _isCanteenExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16.sp,
                              color: AppColors.neonBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 4. Discounts & Vouchers (if any)
          if (widget.discounts.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: const DashedDivider(),
            ),
            Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                children: [
                  for (var discount in widget.discounts)
                    SizedBox(
                      height: 32.h,
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              text: discount.label,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          AppText(
                            text: "-${discount.amount.toStringAsFixed(2)} $currency",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 5. Grand Total: Full-width colored banner at the bottom of the card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.12),
              border: Border(
                top: BorderSide(
                  color: AppColors.neonBlue.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AppText(
                    text: AppStrings.total.tr(),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: "${widget.grandTotal.toStringAsFixed(2)} $currency",
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
