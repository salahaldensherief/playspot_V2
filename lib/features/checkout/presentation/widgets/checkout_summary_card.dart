import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_divider.dart';
import 'package:playspot/art_core/widgets/layout/info_row.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import '../checkout_cubit.dart';
import '../checkout_state.dart';

class CheckoutSummaryCard extends StatelessWidget {
  final CheckoutParams params;

  const CheckoutSummaryCard({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: params.lounge.name,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          SizedBox(height: 4.h),
          AppText(
            text:
                "${params.room.spaceTypeLabel(context.locale.languageCode == 'ar')} - ${params.room.getName(context.locale.languageCode == 'ar')} · ${params.room.controllersCount} ${AppStrings.controllers.tr()} · ${params.room.screenSize} ${AppStrings.screen.tr()}",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          if (params.room.isSimulator || params.room.isVR) ...[
            SizedBox(height: 4.h),
            AppText(
              text: params.room.isSimulator ? AppStrings.simulatorSetup.tr() : AppStrings.vrGearSetup.tr(),
              fontSize: 11.sp,
              color: AppColors.neonBlue,
              fontWeight: FontWeight.w500,
            ),
          ],
          SizedBox(height: 16.h),
          const AppDivider(),
          InfoRow(label: AppStrings.selectDate.tr(), value: params.date.toAppDateString()),
          InfoRow(
              label: AppStrings.startTime.tr(), value: params.startTime.toAppTimeString()),
          InfoRow(
              label: AppStrings.duration.tr(),
              value: params.duration >= 60 
                  ? "${params.duration / 60.0} ${AppStrings.hour_plural.tr(args: [''])}"
                  : "${params.duration} ${AppStrings.min30.tr()}"),
          if (params.playMode != null)
            InfoRow(
              label: AppStrings.playMode.tr(),
              value: params.playMode == 'single' 
                  ? AppStrings.singlePlay.tr() 
                  : AppStrings.multiPlay.tr(),
              valueColor: AppColors.neonBlue,
            ),
          if (params.extraControllers != null && params.extraControllers! > 0)
            InfoRow(
              label: AppStrings.extraControllers.tr(),
              value: "${params.extraControllers}x (+${(params.extraControllers! * (params.extraControllerPrice ?? 0)).toStringAsFixed(2)} ${AppStrings.egp.tr()}/${AppStrings.hour.tr()})",
              valueColor: AppColors.warning,
              prefixIcon: Icons.videogame_asset_outlined,
            ),
          if (params.addOns.isNotEmpty) ...[
            SizedBox(height: 16.h),
            AppText(
              text: AppStrings.addOns.tr(),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8.h),
            ...params.addOns.map((addOn) {
              IconData icon = Icons.local_drink_outlined;
              final name = addOn['name'].toString().toLowerCase();
              if (name.contains('snack') ||
                  name.contains('food') ||
                  name.contains('popcorn') ||
                  name.contains('pizza')) {
                icon = Icons.fastfood_outlined;
              }
              final itemTotal = (addOn['price'] as num) * (addOn['quantity'] as num);
              return InfoRow(
                label: "${addOn['quantity']}x ${addOn['name']}",
                value:
                    "${itemTotal.toDouble().toStringAsFixed(2)} ${AppStrings.egp.tr()}",
                labelColor: AppColors.white,
                fontSize: 14.sp,
                prefixIcon: icon,
              );
            }),
          ],
          const AppDivider(),
          SizedBox(height: 16.h),
          BlocBuilder<CheckoutCubit, CheckoutState>(
            buildWhen: (previous, current) => previous.discountAmount != current.discountAmount,
            builder: (context, state) {
              final isArabic = context.locale.languageCode == 'ar';
              final roomOriginalSubtotal = params.originalRoomSubtotal;
              final roomDiscount = params.discountAmount;
              final voucherDiscount = state.discountAmount;
              final finalPrice = params.totalPrice - voucherDiscount;

              return Column(
                children: [
                  // 1. Original Room Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: isArabic ? "سعر الغرفة الأصلي" : "Original Room Price",
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                      AppText(
                        text: "${roomOriginalSubtotal.toInt()} ${AppStrings.egp.tr()}",
                        fontSize: 14.sp,
                        color: roomDiscount > 0 ? AppColors.textSecondary : AppColors.white,
                        textDecoration: roomDiscount > 0 ? TextDecoration.lineThrough : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // 2. Offer Discount Line (Room or Lounge offer)
                  if (roomDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: params.discountLabel ?? (isArabic ? "خصم العرض" : "Offer Discount"),
                          fontSize: 14.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                        AppText(
                          text: "-${roomDiscount.toInt()} ${AppStrings.egp.tr()}",
                          fontSize: 14.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                  ],

                  // 3. Voucher Discount Line (if applied)
                  if (voucherDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: isArabic ? "كوبون الخصم" : "Voucher Discount",
                          fontSize: 14.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                        AppText(
                          text: "-${voucherDiscount.toInt()} ${AppStrings.egp.tr()}",
                          fontSize: 14.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                  ],

                  // 4. Canteen / Add-ons Total (Not discounted by room offer)
                  if (params.addonsTotal > 0 || params.addOns.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          text: AppStrings.addOns.tr(),
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        AppText(
                          text: "${params.addonsTotal.toInt()} ${AppStrings.egp.tr()}",
                          fontSize: 14.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                  ],

                  const AppDivider(),
                  SizedBox(height: 12.h),

                  // 5. Final Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: AppStrings.total.tr(),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      AppText(
                        text: "${finalPrice.toInt()} ${AppStrings.egp.tr()}",
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonBlue,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
