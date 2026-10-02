import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/widgets/rating/rating_display_widget.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungeRatingSummary extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeRatingSummary({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (lounge.rating > 0 || (lounge.totalReviews ?? 0) > 0) ...[
        RatingDisplayWidget(rating: lounge.rating, starSize: 18, spacing: 2),
        Text(
          lounge.totalReviews == null
              ? lounge.rating.toStringAsFixed(1)
              : 'lounge_rating_summary'.tr(
                  namedArgs: {
                    'rating': lounge.rating.toStringAsFixed(1),
                    'count': '${lounge.totalReviews}',
                  },
                ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ] else if (lounge.totalReviews == 0)
        Text(
          'lounge_no_reviews'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
    ],
  );
}
