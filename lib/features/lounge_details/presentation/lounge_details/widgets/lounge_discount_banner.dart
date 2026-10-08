import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungeDiscountBanner extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeDiscountBanner({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.06),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_offer_outlined, color: AppColors.warning, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            lounge.getDiscountTitle(context.locale.languageCode == 'ar') ??
                AppStrings.activeOffer.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${lounge.discountPercentage}%',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
