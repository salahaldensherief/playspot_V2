import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';

class QrLocationDialog extends StatelessWidget {
  final String mapsLink;
  final String loungeName;

  const QrLocationDialog({
    super.key,
    required this.mapsLink,
    required this.loungeName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
      child: GlassContainer(
        borderRadius: 30,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 24.h),
              AppText(
                text: "loungeLocation".tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: "Orbitron",
              ),
              SizedBox(height: 8.h),
              AppText(
                text: loungeName,
                fontSize: 14.sp,
                color: AppColors.neonBlue,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: QrImageView(
                  data: mapsLink,
                  version: QrVersions.auto,
                  size: 200.w,
                  gapless: false,
                ),
              ),
              SizedBox(height: 30.h),
              AppText(
                text: "scanDirections".tr(),
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 20.h),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: AppText(
                  text: "close".tr().toUpperCase(),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
