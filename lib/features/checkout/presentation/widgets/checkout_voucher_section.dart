import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';
import 'checkout_voucher_picker_tile.dart';

class CheckoutVoucherSection extends StatelessWidget {
  final TextEditingController voucherController;
  final VoidCallback onVoucherChanged;

  const CheckoutVoucherSection({
    super.key,
    required this.voucherController,
    required this.onVoucherChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) => previous.myVouchers != current.myVouchers,
      builder: (context, profileState) {
        final availableVouchers = profileState.myVouchers
            .where((v) => v['status'] == 'active')
            .toList();

        return BlocBuilder<CheckoutCubit, CheckoutState>(
          buildWhen: (previous, current) =>
              previous.selectedVoucher != current.selectedVoucher ||
              previous.discountAmount != current.discountAmount ||
              previous.status != current.status,
          builder: (context, checkoutState) {
            final isVoucherApplied = checkoutState.selectedVoucher != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      text: AppStrings.promoCode.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    if (isVoucherApplied)
                      AppButton(
                        content: ButtonContent(label: AppStrings.remove.tr()),
                        behavior: ButtonBehavior.tap(
                          onTap: () {
                            context.read<CheckoutCubit>().removeVoucher();
                            voucherController.clear();
                            onVoucherChanged();
                          },
                        ),
                        buttonConfig: ButtonConfig(
                          height: 32.h,
                          backgroundColor: Colors.transparent,
                          borderRadius: 8.r,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (isVoucherApplied)
                  _AppliedVoucherCard(
                    voucher: checkoutState.selectedVoucher!,
                    discountAmount: checkoutState.discountAmount,
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: voucherController,
                          hint: AppStrings.referralCodeHint.tr(),
                          onChanged: (_) => onVoucherChanged(),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      AppButton(
                        content: ButtonContent(
                          label: AppStrings.redeem.tr(),
                        ),
                        buttonConfig: ButtonConfig(
                          gradient: voucherController.text.trim().isNotEmpty
                              ? AppColors.primaryGradient
                              : null,
                          backgroundColor: AppColors.cardBackground,
                          borderColor: voucherController.text.trim().isNotEmpty
                              ? AppColors.neonBlue
                              : AppColors.borderDefault,
                          borderRadius: 14.r,
                          width: 110.w,
                          height: 52.h,
                          textStyle: TextStyle(
                            color: voucherController.text.trim().isNotEmpty
                                ? Colors.black
                                : AppColors.neonBlue,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        behavior: ButtonBehavior.tap(
                          isEnabled: voucherController.text.trim().isNotEmpty &&
                              checkoutState.status != CheckoutStatus.loading,
                          onTap: () => context
                              .read<CheckoutCubit>()
                              .applyVoucher(voucherController.text.trim()),
                        ),
                      ),
                    ],
                  ),
                  if (availableVouchers.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    CheckoutVoucherPickerTile(vouchers: availableVouchers),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _AppliedVoucherCard extends StatelessWidget {
  final Map<String, dynamic> voucher;
  final double discountAmount;

  const _AppliedVoucherCard({
    required this.voucher,
    required this.discountAmount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 15,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.confirmation_number_outlined, color: AppColors.success, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: voucher['code'] ?? '',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  AppText(
                    text: discountAmount > 0
                        ? AppStrings.youSaved.tr(args: [discountAmount.toStringAsFixed(0)])
                        : AppStrings.voucherApplied.tr(),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

