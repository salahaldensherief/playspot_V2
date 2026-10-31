import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungePaymentSummary extends StatelessWidget {
  final LoungeModel lounge;
  const LoungePaymentSummary({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final methods = [
      if (lounge.allowCashPayment) AppStrings.loungePaymentCash.tr(),
      if ((lounge.effectiveWalletNumber?.trim().isNotEmpty ?? false))
        AppStrings.loungePaymentWallet.tr(),
      if ((lounge.effectiveInstapayHandle?.trim().isNotEmpty ?? false))
        AppStrings.loungePaymentInstapay.tr(),
    ];
    if (methods.isEmpty && !lounge.requirePrepaidFirstTime) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (methods.isNotEmpty)
          AppText(
            text: AppStrings.loungePaymentMethods.tr(
              namedArgs: {'methods': methods.join(' · ')},
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        if (lounge.requirePrepaidFirstTime)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppText(
              text: AppStrings.loungeFirstBookingPrepaid.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
