import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../data/models/booking_model.dart';

class BookingQrDialog extends StatelessWidget {
  final BookingModel booking;

  const BookingQrDialog({super.key, required this.booking});

  static Future<void> show(BuildContext context, BookingModel booking) {
    return showDialog(
      context: context,
      builder: (_) => BookingQrDialog(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText(
                    text: AppStrings.bookingQrTitle.tr(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20.sp,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

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
                text: booking.loungeName.isNotEmpty
                    ? booking.loungeName
                    : AppStrings.playSpot,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              AppText(
                text: "${booking.roomName} • ${booking.date.toAppDateString()}",
                fontSize: 12.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              AppText(
                text: AppStrings.bookingIdLabel.tr(
                  namedArgs: {'id': booking.id.toString()},
                ),
                fontSize: 11.sp,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              SizedBox(height: 20.h),

              AppButton(
                content: ButtonContent(label: AppStrings.close.tr()),
                buttonConfig: ButtonConfig(
                  height: 44.h,
                  backgroundColor: AppColors.transparent,
                  borderColor: AppColors.borderDefault,
                  borderRadius: 12.r,
                ),
                behavior: ButtonBehavior.tap(
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
