import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../domain/entities/booking_price_quote.dart';

class PriceChangedBottomSheet extends StatelessWidget {
  final double oldPrice;
  final double newPrice;
  final BookingPriceQuote? newQuote;

  const PriceChangedBottomSheet({
    super.key,
    required this.oldPrice,
    required this.newPrice,
    this.newQuote,
  });

  static Future<bool> show(
    BuildContext context, {
    required double oldPrice,
    required double newPrice,
    BookingPriceQuote? newQuote,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PriceChangedBottomSheet(
        oldPrice: oldPrice,
        newPrice: newPrice,
        newQuote: newQuote,
      ),
    );
    return result == true;
  }

  String _getLangCode(BuildContext context) {
    try {
      final easyLoc = EasyLocalization.of(context);
      if (easyLoc != null) return easyLoc.locale.languageCode;
      return Localizations.localeOf(context).languageCode;
    } catch (_) {
      return 'ar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _getLangCode(context) == 'ar';

    return Container(
      constraints: BoxConstraints(maxHeight: 0.85.sh),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: 24,
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Handle Bar
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.price_change_rounded,
                        color: AppColors.warning,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: AppText(
                        text: isArabic ? "تغير سعر الحجز" : "Price Updated",
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Message Body
                AppText(
                  text: isArabic
                      ? "تغير سعر الساعات بناءً على قواعد الذروة الحالية. يرجى مراجعة السعر الجديد قبل إكمال الحجز."
                      : "Hourly rates changed based on current peak rules. Please review the updated pricing before proceeding.",
                  fontSize: 13.sp,
                  color: Colors.white70,
                  height: 1.4,
                ),
                SizedBox(height: 16.h),

                // Price Comparison Box
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (oldPrice > 0) ...[
                        Expanded(
                          child: Column(
                            children: [
                              AppText(
                                text: isArabic ? "السعر السابق" : "Old Price",
                                fontSize: 11.sp,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "${oldPrice.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.white54,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.neonBlue, size: 18.sp),
                      ],
                      Expanded(
                        child: Column(
                          children: [
                            AppText(
                              text: isArabic ? "السعر الجديد الإجمالي" : "New Total Price",
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 4.h),
                            AppText(
                              text: "${newPrice.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Segments Breakdown if available
                if (newQuote != null && newQuote!.segments.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  AppText(
                    text: isArabic ? "تفاصيل فترات السعر:" : "Segment Breakdown:",
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                  SizedBox(height: 6.h),
                  ...newQuote!.segments.map((seg) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        child: Row(
                          children: [
                            Icon(
                              seg.isPeak ? Icons.local_fire_department_rounded : Icons.schedule_rounded,
                              color: seg.isPeak ? AppColors.warning : AppColors.neonBlue,
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            AppText(
                              text: "${seg.from.substring(0, 5)} - ${seg.to.substring(0, 5)}",
                              fontSize: 11.sp,
                              color: Colors.white70,
                            ),
                            const Spacer(),
                            AppText(
                              text: "${seg.amount.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'EGP'}",
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      )),
                ],

                SizedBox(height: 20.h),

                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        content: ButtonContent(
                          label: isArabic ? "تراجع" : "Cancel",
                        ),
                        buttonConfig: ButtonConfig(
                          height: 44.h,
                          backgroundColor: Colors.transparent,
                          borderColor: AppColors.borderDefault,
                          borderRadius: 12.r,
                        ),
                        behavior: ButtonBehavior.tap(
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        content: ButtonContent(
                          label: isArabic ? "متابعة بالسعر الجديد" : "Confirm New Price",
                        ),
                        buttonConfig: ButtonConfig(
                          height: 44.h,
                          backgroundColor: AppColors.neonBlue,
                          borderRadius: 12.r,
                        ),
                        behavior: ButtonBehavior.tap(
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
