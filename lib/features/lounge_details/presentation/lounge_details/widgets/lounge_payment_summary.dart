import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungePaymentSummary extends StatelessWidget {
  final LoungeModel lounge;
  const LoungePaymentSummary({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final methods = [
      if (lounge.allowCashPayment) 'lounge_payment_cash'.tr(),
      if ((lounge.effectiveWalletNumber?.trim().isNotEmpty ?? false))
        'lounge_payment_wallet'.tr(),
      if ((lounge.effectiveInstapayHandle?.trim().isNotEmpty ?? false))
        'lounge_payment_instapay'.tr(),
    ];
    if (methods.isEmpty && !lounge.requirePrepaidFirstTime) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (methods.isNotEmpty)
          Text(
            'lounge_payment_methods'.tr(
              namedArgs: {'methods': methods.join(' · ')},
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        if (lounge.requirePrepaidFirstTime)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'lounge_first_booking_prepaid'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
