import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/models/active_session_model.dart';

class StationInfo extends StatelessWidget {
  final ActiveSessionModel session;
  const StationInfo({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final bookingCode = session.bookingId.length >= 6
        ? session.bookingId.substring(0, 6).toUpperCase()
        : session.bookingId.toUpperCase();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.black, 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.withOpacity(AppColors.neonBlue, 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.withOpacity(AppColors.neonBlue, 0.25)),
            ),
            child: Icon(
              Icons.sports_esports_rounded,
              color: AppColors.neonBlue,
              size: 26.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  text: session.loungeName,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: "${session.roomName} • ${session.deviceName}",
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: session.bookingId));
              GameHudToast.show(
                context,
                AppStrings.bookingIdCopied.tr(),
                type: ToastType.info,
              );
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.withOpacity(AppColors.neonBlue, 0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.withOpacity(AppColors.neonBlue, 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    text: AppStrings.station.tr(),
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12.sp, color: AppColors.neonBlue),
                      SizedBox(width: 4.w),
                      AppText(
                        text: "#$bookingCode",
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
