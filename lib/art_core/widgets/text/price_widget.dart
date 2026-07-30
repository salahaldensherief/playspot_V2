import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';

class PriceWidget extends StatelessWidget {
  final double price;
  final double? fontSize;
  final double? currencyFontSize;
  final Color? color;
  final bool showCurrency;
  final String? fontFamily;

  const PriceWidget({
    super.key,
    required this.price,
    this.fontSize,
    this.currencyFontSize,
    this.color,
    this.showCurrency = true,
    this.fontFamily = 'Orbitron',
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "${price.toInt()}",
            style: TextStyle(
              color: color ?? AppColors.neonBlue,
              fontSize: fontSize ?? 18.sp,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
            ),
          ),
          if (showCurrency)
            TextSpan(
              text: " ${AppStrings.egp.tr()}",
              style: TextStyle(
                color: color ?? AppColors.neonBlue,
                fontSize: currencyFontSize ?? 10.sp,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
              ),
            ),
        ],
      ),
    );
  }
}
