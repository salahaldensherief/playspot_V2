import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/active_session.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/cards/order_summary_card.dart';

class BillingBreakdownWidget extends StatelessWidget {
  final ActiveSession session;

  const BillingBreakdownWidget({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> sessionRows = [];
    if (session.extensionsPrice > 0) {
      sessionRows.add({
        'label': AppStrings.extensions.tr(),
        'value': "${session.extensionsPrice.toStringAsFixed(2)} ${AppStrings.egp.tr()}",
        'color': AppColors.neonBlue,
      });
    }

    final canteenItems = session.orders.map((order) {
      return OrderItemData(
        name: order.name,
        quantity: order.quantity,
        price: order.price,
      );
    }).toList();

    return OrderSummaryCard(
      title: AppStrings.billingBreakdown.tr(),
      subtitle: "${session.loungeName} • ${session.roomName} (${session.deviceName})",
      statusText: session.status == 'active'
          ? AppStrings.statusActive.tr()
          : AppStrings.completed.tr(),
      statusColor: session.status == 'active' ? AppColors.neonBlue : AppColors.success,
      baseCostLabel: AppStrings.baseCost.tr(),
      baseCostAmount: session.basePrice,
      sessionDetailsRows: sessionRows,
      canteenItems: canteenItems,
      grandTotal: session.grandTotal,
    );
  }
}
