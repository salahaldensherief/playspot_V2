import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/layout/info_row.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class BillingBreakdownWidget extends StatelessWidget {
  final ActiveSessionModel session;

  const BillingBreakdownWidget({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: "billingBreakdown".tr(),
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 12.h),
          InfoRow(
            label: "baseCost".tr(),
            value: "${session.basePrice.toStringAsFixed(2)} ${"egp".tr()}",
          ),
          if (session.extensionsPrice > 0)
            InfoRow(
              label: "extensions".tr(),
              value: "${session.extensionsPrice.toStringAsFixed(2)} ${"egp".tr()}",
            ),
          if (session.orders.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Divider(color: AppColors.divider),
            SizedBox(height: 8.h),
            ...session.orders.map((order) => InfoRow(
                  label: "${order.name} (x${order.quantity})",
                  value: "${order.total.toStringAsFixed(2)} ${"egp".tr()}",
                  fontSize: 13.sp,
                )),
          ],
          SizedBox(height: 12.h),
          Divider(color: AppColors.divider, thickness: 1),
          SizedBox(height: 8.h),
          InfoRow(
            label: "total".tr(),
            value: "${session.grandTotal.toStringAsFixed(2)} ${"egp".tr()}",
            valueColor: AppColors.neonBlue,
            fontSize: 18.sp,
          ),
        ],
      ),
    );
  }
}
