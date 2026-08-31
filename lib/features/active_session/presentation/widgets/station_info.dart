import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.videogame_asset_rounded, color: AppColors.neonBlue, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: session.loungeName,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: "${session.roomName} - ${session.deviceName}",
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                text: AppStrings.station.tr(),
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
              AppText(
                text: "#${session.bookingId.substring(0, 6).toUpperCase()}",
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
