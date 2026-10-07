import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_rating_summary.dart';
import 'lounge_location_summary.dart';
import 'lounge_operating_hours.dart';
import 'lounge_payment_summary.dart';
import 'lounge_room_comparison.dart';
import 'lounge_detail_panel.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class LoungeInfoSection extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeInfoSection({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final description =
        (lounge.getDescription(context.locale.languageCode == 'ar') ?? '')
            .trim();
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoungeDetailPanel(
              titleKey: 'lounge_about_section',
              icon: Icons.info_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LoungeRatingSummary(lounge: lounge),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppText(
                        text: description,
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        color: Colors.white70,
                        maxLines: 2,
                        showAllTextOnTap: true,
                      ),
                    ),
                ],
              ),
            ),
            LoungeDetailPanel(
              titleKey: 'lounge_visit_section',
              collapsible: true,
              icon: Icons.near_me_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LoungeOperatingHours(lounge: lounge),
                  const Divider(height: 28, color: Colors.white12),
                  LoungeLocationSummary(lounge: lounge),
                ],
              ),
            ),
            if (lounge.allowCashPayment ||
                (lounge.effectiveWalletNumber?.trim().isNotEmpty ?? false) ||
                (lounge.effectiveInstapayHandle?.trim().isNotEmpty ?? false) ||
                lounge.requirePrepaidFirstTime)
              LoungeDetailPanel(
                titleKey: 'lounge_payment_section',
                collapsible: true,
                icon: Icons.account_balance_wallet_outlined,
                child: LoungePaymentSummary(lounge: lounge),
              ),
            const LoungeRoomComparison(),
          ],
        ),
      ),
    );
  }
}
