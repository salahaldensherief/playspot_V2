import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
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
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: AppText(
                      text: promo.getTag(isArabic).toUpperCase(),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
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
