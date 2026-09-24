import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class BookingRejectedDialog extends StatelessWidget {
  final String rejectionReason;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const BookingRejectedDialog({
    super.key,
    required this.rejectionReason,
    required this.onRetry,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required String rejectionReason,
    required VoidCallback onRetry,
    required VoidCallback onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookingRejectedDialog(
        rejectionReason: rejectionReason,
        onRetry: onRetry,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GlassContainer(
        borderRadius: 24,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  color: AppColors.danger,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 16.h),
              AppText(
                text: isArabic ? 'تم رفض الحجز من الصالة' : 'Booking Declined',
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),

              // Rejection Reason Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: isArabic ? 'سبب الرفض الصادر من الصالة:' : 'Reason from venue:',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                    SizedBox(height: 6.h),
                    AppText(
                      text: rejectionReason.isNotEmpty
                          ? rejectionReason
                          : (isArabic ? 'لم يتم تحديد سبب الرفض' : 'No specific reason provided.'),
                      fontSize: 13.sp,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      content: ButtonContent(
                        label: isArabic ? 'إلغاء' : 'Cancel',
                      ),
                      buttonConfig: ButtonConfig(
                        height: 48.h,
                        backgroundColor: AppColors.transparent,
                        borderColor: AppColors.borderDefault,
                        borderRadius: 12.r,
                      ),
                      behavior: ButtonBehavior.tap(
                        onTap: () {
                          Navigator.pop(context);
                          onCancel();
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppButton(
                      content: ButtonContent(
                        label: isArabic ? 'إعادة المحاولة' : 'Retry Payment',
                      ),
                      buttonConfig: ButtonConfig(
                        height: 48.h,
                        gradient: AppColors.primaryGradient,
                        borderRadius: 12.r,
                      ),
                      behavior: ButtonBehavior.tap(
                        onTap: () {
                          Navigator.pop(context);
                          onRetry();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
