import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../data/models/promo_model.dart';

class PromoCard extends StatelessWidget {
  final PromoModel promo;
  final VoidCallback? onTap;

  const PromoCard({super.key, required this.promo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: 2.horizontalPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.r24),
          gradient: LinearGradient(
            colors: promo.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20.w,
              bottom: -20.h,
              child: Icon(
                promo.icon,
                size: 150.sp,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: 20.allPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: 8.horizontalPadding + 4.verticalPadding,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                    ),
                    child: AppText(
                      text: promo.getTag(isArabic).toUpperCase(),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  8.verticalSpace,
                  AppText(
                    text: promo.getTitle(isArabic),
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
