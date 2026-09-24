import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

class BookingConfirmedDialog extends StatelessWidget {
  final BookingModel booking;

  const BookingConfirmedDialog({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, BookingModel booking) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookingConfirmedDialog(booking: booking),
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
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 16.h),
              AppText(
                text: isArabic ? 'تم تأكيد حجزك بنجاح! 🎉' : 'Booking Confirmed!',
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              AppText(
                text: isArabic
                    ? 'وافقت الصالة على تحويلك. يرجى إبراز رمز QR عند الوصول.'
                    : 'The venue approved your payment. Show this QR code upon arrival.',
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // QR Code Container
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: QrImageView(
                  data: 'playspot://booking/${booking.id}',
                  version: QrVersions.auto,
                  size: 180.w,
                  gapless: false,
                ),
              ),
              SizedBox(height: 16.h),

              AppText(
                text: '${booking.loungeName} · ${booking.roomName}',
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              AppText(
                text: 'ID: #${booking.id}',
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 24.h),

              AppButton(
                content: ButtonContent(
                  label: AppStrings.viewMyBookings.tr(),
                ),
                buttonConfig: ButtonConfig(
                  height: 48.h,
                  gradient: AppColors.primaryGradient,
                  borderRadius: 12.r,
                ),
                behavior: ButtonBehavior.tap(
                  onTap: () {
                    Navigator.pop(context);
                    context.goNamed(RouterKeys.home, extra: 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
