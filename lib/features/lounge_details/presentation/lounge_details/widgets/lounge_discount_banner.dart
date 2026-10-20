import 'package:playspot/art_core/widgets/text/app_text.dart';
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
        const Icon(Icons.local_offer_rounded, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: AppText(
            text:
                lounge.getDiscountTitle(context.locale.languageCode == 'ar') ??
                AppStrings.activeOffer.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppText(
          text: '${lounge.discountPercentage}%',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
