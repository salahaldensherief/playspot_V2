import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/entities/order_item.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/cards/order_summary_card.dart';
import '../../../../art_core/widgets/layout/dashed_divider.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class BillingBreakdownWidget extends StatelessWidget {
  final ActiveSession session;

  const BillingBreakdownWidget({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.isOpenTime &&
        (session.status == 'active' || session.status == 'in_progress')) {
      final policy = session.openTimePricingSnapshot;
      final rate = policy['effective_hourly_rate'];
      final minimum = policy['minimum_minutes'];
      final rounding = policy['rounding_minutes'];

      final activeOrders = session.orders
          .where((item) => !item.isCancelled)
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.neonBlue.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.openTimeElapsed.tr(),
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonBlue,
                ),
                SizedBox(height: 8.h),
                if (rate is num)
                  AppText(
                    text: AppStrings.openTimePolicy.tr(
                      namedArgs: {'rate': rate.toStringAsFixed(2)},
                    ),
                  ),
                if (minimum is num)
                  AppText(
                    text: AppStrings.openTimeMinimum.tr(
                      namedArgs: {'minutes': minimum.toString()},
                    ),
                  ),
                if (rounding is num)
                  AppText(
                    text: AppStrings.openTimeRounding.tr(
                      namedArgs: {'minutes': rounding.toString()},
                    ),
                  ),
                SizedBox(height: 8.h),
                AppText(
                  text: AppStrings.openTimeBillPending.tr(),
                  color: AppColors.textSecondary,
                ),
                if (activeOrders.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  AppText(
                    text: AppStrings.openTimeCanteenCharges.tr(
                      namedArgs: {
                        'amount': session.ordersTotal.toStringAsFixed(2),
                      },
                    ),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
          if (session.orders.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 12.h),
                    child: Row(
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
                                  text: AppStrings.canteenMenu.tr(),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.neonBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: AppText(
                            text: AppStrings.inProgress.tr(),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neonBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: const DashedDivider(),
                  ),
                  Padding(
                    padding: EdgeInsets.all(18.w),
                    child: Column(
                      children: [
                        for (var item in session.orders)
                          _buildCanteenOrderRow(context, item),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: const DashedDivider(),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
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
                            text: AppStrings.openTimeCanteenCharges.tr(
                              namedArgs: {
                                'amount': session.ordersTotal.toStringAsFixed(
                                  2,
                                ),
                              },
                            ),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neonBlue,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    final List<Map<String, dynamic>> sessionRows = [];
    if (session.extensionsPrice > 0) {
      sessionRows.add({
        'label': AppStrings.extensions.tr(),
        'value':
            "${session.extensionsPrice.toStringAsFixed(2)} ${AppStrings.egp.tr()}",
        'color': AppColors.neonBlue,
      });
    }

    bool isArabic = false;
    try {
      isArabic = context.locale.languageCode == 'ar';
    } catch (_) {
      try {
        isArabic = Localizations.localeOf(context).languageCode == 'ar';
      } catch (_) {}
    }

    final canteenItems = session.orders.map((order) {
      final displayName = isArabic
          ? (order.nameAr ?? order.name)
          : (order.nameEn ?? order.name);
      return OrderItemData(
        name: displayName,
        quantity: order.quantity,
        price: order.price,
        totalPrice: order.totalPriceOverride,
        status: order.status,
      );
    }).toList();

    return OrderSummaryCard(
      title: AppStrings.billingBreakdown.tr(),
      subtitle: session.status == 'active' || session.status == 'in_progress'
          ? null
          : "${session.loungeName} • ${session.roomName} (${session.deviceName})",
      statusText: session.status == 'active' || session.status == 'in_progress'
          ? null
          : AppStrings.completed.tr(),
      statusColor: AppColors.success,
      baseCostLabel: AppStrings.baseCost.tr(),
      baseCostAmount: session.basePrice,
      sessionDetailsRows: sessionRows,
      canteenItems: canteenItems,
      grandTotal: session.grandTotal,
    );
  }

  Widget _buildCanteenOrderRow(BuildContext context, OrderItem order) {
    final isCancelled = order.isCancelled;
    bool isArabic = false;
    try {
      isArabic = context.locale.languageCode == 'ar';
    } catch (_) {
      try {
        isArabic = Localizations.localeOf(context).languageCode == 'ar';
      } catch (_) {}
    }
    final displayName = isArabic
        ? (order.nameAr ?? order.name)
        : (order.nameEn ?? order.name);

    String currency = 'EGP';
    try {
      currency = AppStrings.egp.tr();
    } catch (_) {}

    return SizedBox(
      height: 36.h,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: AppText(
              text: "${order.quantity}×",
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.neonBlue,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: AppText(
              text: displayName,
              fontSize: 12.5.sp,
              maxLines: 1,
              color: isCancelled ? AppColors.textSecondary : Colors.white,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (order.status != null && order.status!.isNotEmpty) ...[
            SizedBox(width: 4.w),
            _buildOrderStatusBadge(order.status!),
          ],
          SizedBox(width: 6.w),
          AppText(
            text: "${order.total.toStringAsFixed(2)} $currency",
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: isCancelled ? AppColors.textSecondary : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    String label;
    Color color;
    switch (status.toLowerCase()) {
      case 'preparing':
        label = AppStrings.orderStatusPreparing.tr();
        color = AppColors.neonBlue;
        break;
      case 'delivered':
        label = AppStrings.orderStatusDelivered.tr();
        color = AppColors.success;
        break;
      case 'completed':
        label = AppStrings.orderStatusCompleted.tr();
        color = AppColors.success;
        break;
      case 'cancelled':
        label = AppStrings.orderStatusCancelled.tr();
        color = AppColors.danger;
        break;
      case 'pending':
      default:
        label = AppStrings.orderStatusPending.tr();
        color = AppColors.warning;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: AppText(
        text: label,
        fontSize: 9.5.sp,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}
