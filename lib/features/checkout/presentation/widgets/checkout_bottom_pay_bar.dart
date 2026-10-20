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
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';
import 'vodafone_cash_bottom_sheet.dart';

class CheckoutBottomPayBar extends StatelessWidget {
  final CheckoutParams params;

  const CheckoutBottomPayBar({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.discountAmount != current.discountAmount ||
          previous.serverQuote != current.serverQuote ||
          previous.selectedMethod != current.selectedMethod ||
          previous.isHoldExpired != current.isHoldExpired,
      builder: (context, state) {
        final finalPrice =
            state.serverFinalTotal ??
            params.calculateFinalPrice(state.discountAmount);
        final quoteFailed =
            state.status == CheckoutStatus.failure &&
            state.serverFinalTotal == null &&
            !state.isHoldExpired;

        final buttonText = state.status == CheckoutStatus.loading
            ? AppStrings.processing.tr()
            : quoteFailed
            ? AppStrings.retryPriceCalculation.tr()
            : (state.selectedMethod == PaymentMethod.cash
                  ? AppStrings.confirmBookingWithPrice.tr(
                      args: [finalPrice.toStringAsFixed(2)],
                    )
                  : AppStrings.payNowWithPrice.tr(
                      args: [finalPrice.toStringAsFixed(2)],
                    ));

        final bool isButtonEnabled =
            state.status != CheckoutStatus.loading &&
            !state.isHoldExpired &&
            (state.serverFinalTotal != null || quoteFailed);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          color: AppColors.scaffoldBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          text: AppStrings.totalPrice.tr(),
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                        PriceWidget(
                          price: finalPrice,
                          fontSize: 18.sp,
                          color: AppColors.neonBlue,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: BlocSelector<CheckoutCubit, CheckoutState, String>(
                      selector: (current) => current.isHoldExpired
                          ? AppStrings.holdExpiredLabel.tr()
                          : current.formattedRemainingTime,
                      builder: (context, remaining) => Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppText(
                            text: AppStrings.remainingTime.tr(),
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                          AppText(
                            text: remaining,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: state.isHoldExpired
                                ? AppColors.danger
                                : AppColors.warning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              AppButton(
                content: ButtonContent(
                  label: state.isHoldExpired
                      ? AppStrings.holdExpiredLabel.tr()
                      : buttonText,
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: isButtonEnabled,
                  onTap: () {
                    if (state.isHoldExpired) return;

                    if (quoteFailed) {
                      context.read<CheckoutCubit>().retryServerQuote();
                      return;
                    }

                    if (state.selectedMethod == PaymentMethod.cash) {
                      context.read<CheckoutCubit>().processPayment(
                        params,
                        isArabic: context.locale.languageCode == 'ar',
                        paymentMethod: 'cash',
                      );
                    } else {
                      final initialMethod =
                          state.selectedMethod == PaymentMethod.instaPay
                          ? 'InstaPay'
                          : 'Vodafone Cash';
                      VodafoneCashBottomSheet.show(
                        context: context,
                        amount: finalPrice,
                        loungeName: params.lounge.name,
                        walletNumber: params.lounge.effectiveWalletNumber ?? '',
                        instaPayAccount: params.lounge.effectiveInstapayHandle,
                        initialMethod: initialMethod,
                        onConfirm:
                            (
                              method,
                              receiptFile,
                              senderAccount,
                              transactionRef,
                            ) {
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
