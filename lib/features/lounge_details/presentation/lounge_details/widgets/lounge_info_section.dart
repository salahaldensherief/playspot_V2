import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_rating_summary.dart';
import 'lounge_location_summary.dart';
import 'lounge_operating_hours.dart';
import 'lounge_payment_summary.dart';
import 'lounge_room_comparison.dart';

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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoungeRatingSummary(lounge: lounge),
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    description,
                    style: const TextStyle(height: 1.5, color: Colors.white70),
                  ),
                ),
              const Divider(height: 24, color: Colors.white12),
              LoungeLocationSummary(lounge: lounge),
              const SizedBox(height: 12),
              LoungeOperatingHours(lounge: lounge),
              const SizedBox(height: 12),
              LoungePaymentSummary(lounge: lounge),
              const LoungeRoomComparison(),
            ],
          ),
        ),
      ),
    );
  }
}
