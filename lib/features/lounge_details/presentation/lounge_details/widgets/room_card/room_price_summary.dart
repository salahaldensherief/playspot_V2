import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import '../../room_rate_presentation.dart';

class RoomPriceSummary extends StatelessWidget {
  final RoomRatePresentation rate;
  final Color color;
  const RoomPriceSummary({super.key, required this.rate, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (rate.hasOffer)
        AppText(
          text: '${rate.original} ${AppStrings.egp.tr()}',
          fontSize: 11,
          color: AppColors.textSecondary,
          textDecoration: TextDecoration.lineThrough,
        ),
      PriceWidget(
        price: rate.effective,
        fontSize: 18,
        currencyFontSize: 12,
        color: rate.hasOffer ? AppColors.success : color,
      ),
      AppText(
        text: AppStrings.perHour.tr(),
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ],
  );
}
