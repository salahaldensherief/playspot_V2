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
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';
import 'vodafone_cash_bottom_sheet.dart';

class CheckoutBottomPayBar extends StatelessWidget {
  final CheckoutParams params;

  const CheckoutBottomPayBar({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.discountAmount != current.discountAmount ||
          previous.selectedMethod != current.selectedMethod ||
          previous.isHoldExpired != current.isHoldExpired,
      builder: (context, state) {
        final finalPrice = params.totalPrice - state.discountAmount;
        final buttonText = state.status == CheckoutStatus.loading
            ? AppStrings.processing.tr()
            : (state.selectedMethod == PaymentMethod.cash
                ? AppStrings.confirmBookingWithPrice.tr(args: [finalPrice.toStringAsFixed(2)])
                : AppStrings.payNowWithPrice.tr(args: [finalPrice.toStringAsFixed(2)]));

        final bool isButtonEnabled = state.status != CheckoutStatus.loading && !state.isHoldExpired;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          color: AppColors.scaffoldBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                content: ButtonContent(
                  label: state.isHoldExpired
                      ? (context.locale.languageCode == 'ar'
                          ? 'انتهت فترة حجز الموعد'
                          : 'Hold Expired')
                      : buttonText,
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: isButtonEnabled,
                  onTap: () {
                    if (state.isHoldExpired) return;

                    if (state.selectedMethod == PaymentMethod.cash) {
                      context.read<CheckoutCubit>().processPayment(
                        params,
                        isArabic: context.locale.languageCode == 'ar',
                        paymentMethod: 'cash',
                      );
                    } else {
                      final initialMethod = state.selectedMethod == PaymentMethod.instaPay
                          ? 'InstaPay'
                          : 'Vodafone Cash';
                      VodafoneCashBottomSheet.show(
                        context: context,
                        amount: finalPrice,
                        loungeName: params.lounge.name,
                        walletNumber: params.lounge.effectiveWalletNumber ?? '',
                        instaPayAccount: params.lounge.effectiveInstapayHandle,
                        initialMethod: initialMethod,
                        onConfirm: (method, receiptFile, senderAccount, transactionRef) {
                          context.read<CheckoutCubit>().processPayment(
                            params,
                            isArabic: context.locale.languageCode == 'ar',
                            receiptFile: receiptFile,
                            paymentMethod: 'manual_transfer',
                            senderAccount: senderAccount,
                            senderWalletPhone: senderAccount,
                            transactionReference: transactionRef,
                          );
                        },
                      );
                    }
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 55.h,
                  borderRadius: 15.r,
                  gradient: state.isHoldExpired
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.neonBlue, AppColors.neonPurple],
                        ),
                  backgroundColor: state.isHoldExpired
                      ? AppColors.textSecondary.withValues(alpha: 0.3)
                      : AppColors.transparent,
                ),
              ),
              const SafeBottomSpacer(extraPadding: 40),
            ],
          ),
        );
      },
    );
  }
}
