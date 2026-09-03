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
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.black, 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: AppColors.neonBlue,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              AppText(
                text: "billingBreakdown".tr(),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          InfoRow(
            label: "baseCost".tr(),
            value: "${session.basePrice.toStringAsFixed(2)} ${"egp".tr()}",
          ),
          if (session.extensionsPrice > 0) ...[
            SizedBox(height: 6.h),
            InfoRow(
              label: "extensions".tr(),
              value: "${session.extensionsPrice.toStringAsFixed(2)} ${"egp".tr()}",
            ),
          ],
          if (session.orders.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Divider(color: AppColors.divider),
            SizedBox(height: 8.h),
            ...session.orders.map((order) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: InfoRow(
                    label: "${order.name} (x${order.quantity})",
                    value: "${order.total.toStringAsFixed(2)} ${"egp".tr()}",
                    fontSize: 13.sp,
                  ),
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
