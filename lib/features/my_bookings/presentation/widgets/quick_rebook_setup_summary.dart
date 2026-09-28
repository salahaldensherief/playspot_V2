import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../data/models/booking_model.dart';
import '../quick_rebook_state.dart';

class QuickRebookSetupSummary extends StatelessWidget {
  final BookingModel booking;
  final QuickRebookState state;

  const QuickRebookSetupSummary({
    super.key,
    required this.booking,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final loungeName = state.lounge?.name ?? booking.loungeName;
    final roomName =
        state.room?.getDisplayTitle(isArabic) ?? booking.roomName;
    final playMode = state.pastBooking?.playMode == 'multi'
        ? AppStrings.multiPlay.tr()
        : AppStrings.singlePlay.tr();
    final durationHours = state.durationMinutes / 60;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: AppColors.neonBlue,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: AppText(
                      text: '$loungeName • $roomName',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.gamepad_outlined,
                    color: AppColors.textSecondary,
                    size: 14.sp,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: AppText(
                      text:
                          '$playMode • ${durationHours.toStringAsFixed(durationHours % 1 == 0 ? 0 : 1)} ${AppStrings.hour.tr()}',
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.removedAddonNames.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppText(
                    text: AppStrings.quickRebookRemovedAddons.tr(
                      args: [state.removedAddonNames.join(', ')],
                    ),
                    fontSize: 11.sp,
                    color: AppColors.warning,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
