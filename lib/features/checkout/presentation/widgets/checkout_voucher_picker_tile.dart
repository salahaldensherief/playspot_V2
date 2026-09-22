import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

import '../checkout_cubit.dart';

class CheckoutVoucherPickerTile extends StatelessWidget {
  final List<Map<String, dynamic>> vouchers;

  const CheckoutVoucherPickerTile({
    super.key,
    required this.vouchers,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showVoucherPickerSheet(context, vouchers),
      child: GlassContainer(
        borderRadius: 15,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: AppColors.neonBlue),
              SizedBox(width: 12.w),
              AppText(
                text: AppStrings.selectVoucher.tr(),
                fontSize: 14.sp,
                color: Colors.white,
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoucherPickerSheet(BuildContext context, List<Map<String, dynamic>> vouchers) {
    final checkoutCubit = context.read<CheckoutCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.r))),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              text: AppStrings.availableVouchers.tr(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 20.h),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vouchers.length,
                separatorBuilder: (_, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final voucher = vouchers[index];
                  return GestureDetector(
                    onTap: () {
                      checkoutCubit.selectVoucher(voucher);
                      Navigator.pop(sheetContext);
                    },
                    child: GlassContainer(
                      borderRadius: 15,
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  text: voucher['code'] ?? '',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonBlue,
                                ),
                                AppText(
                                  text: _getRewardDescription(voucher),
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  String _getRewardDescription(Map<String, dynamic> voucher) {
    if (voucher['reward_type'] == 'free_hour') {
      return AppStrings.freeHourReward.tr();
    }
    final val = voucher['reward_value']?.toString() ?? '0';
    return AppStrings.discountAmountReward.tr(args: [val]);
  }
}
