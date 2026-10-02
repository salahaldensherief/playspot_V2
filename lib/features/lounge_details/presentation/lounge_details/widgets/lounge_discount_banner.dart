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
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_offer_rounded, color: Colors.black),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            lounge.getDiscountTitle(context.locale.languageCode == 'ar') ??
                '${lounge.discountPercentage}% ${AppStrings.discount.tr()}',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
