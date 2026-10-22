import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/active_session.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/cards/order_summary_card.dart';
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.openTimeElapsed.tr(),
              fontWeight: FontWeight.bold,
              color: AppColors.neonBlue,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            AppText(
              text: AppStrings.openTimeBillPending.tr(),
              color: AppColors.textSecondary,
            ),
          ],
        ),
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

    final canteenItems = session.orders.map((order) {
      return OrderItemData(
        name: order.name,
        quantity: order.quantity,
        price: order.price,
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
}
