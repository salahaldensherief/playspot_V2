import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/utils/extensions/date_time_extensions.dart';
import '../../../../core/cache/preference_manager.dart';
import '../../../../core/di.dart';
import '../../data/models/booking_model.dart';
import 'package:map_launcher/map_launcher.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const BookingCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = booking.status == 'upcoming' || booking.status == 'pending';
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AppText(
                  text: booking.loungeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              SizedBox(width: 8.w),
              _buildStatusBadge(),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: AppColors.textSecondary, size: 16.sp),
              SizedBox(width: 4.w),
              Expanded(
                child: AppText(
                  text: booking.loungeLocation,
                  fontSize: 12.sp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AppText(
            text: "${booking.spaceType ?? ''} - ${booking.roomName}${booking.playMode != null ? ' (${booking.playMode == 'single' ? AppStrings.singlePlay.tr() : AppStrings.multiPlay.tr()})' : ''} · ${booking.controllersCount} Controllers · ${booking.screenSize}",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: AppColors.neonBlue, size: 16.sp),
              SizedBox(width: 8.w),
              AppText(
                text: booking.date.toAppDateString(),
                fontSize: 14.sp,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.neonBlue, size: 16.sp),
              SizedBox(width: 8.w),
              AppText(
                text: booking.startTime.toAppTimeString(),
                fontSize: 14.sp,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          if (isUpcoming) ...[
            SizedBox(height: 16.h),
            _buildCountdownBanner(),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    content: ButtonContent(label: AppStrings.getDirections.tr()),
                    behavior: ButtonBehavior.tap(
                      onTap: () async {
                        if (booking.lat != null && booking.lng != null) {
                          final pref = sl<PreferenceManager>();
                          final userLat = double.tryParse(pref.latitude());
                          final userLng = double.tryParse(pref.longitude());

                          await MapLauncher.directions(
                            Location.coords(
                              booking.lat!,
                              booking.lng!,
                              title: booking.loungeName,
                            ),
                            from: (userLat != null && userLng != null)
                                ? Location.coords(userLat, userLng, title: "My Location")
                                : null,
                          ).show();
                        }                        },
                    ),
                    buttonConfig: ButtonConfig(
                      height: 45.h,
                      borderRadius: 12.r,
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                AppButton(
                  content: ButtonContent(
                    label: AppStrings.cancel.tr(),
                  ),
                  behavior: ButtonBehavior.tap(onTap: onCancel),
                  buttonConfig: ButtonConfig(
                    height: 45.h,
                    width: 100.w,
                    borderRadius: 12.r,
                    backgroundColor: AppColors.transparent,
                    borderColor: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    switch (booking.status) {
      case 'upcoming':
        color = AppColors.success;
        text = AppStrings.confirmed.tr();
        break;
      case 'pending':
        color = AppColors.warning;
        text = "pending".tr();
        break;
      case 'cancelled':
        color = AppColors.danger;
        text = AppStrings.cancelled.tr();
        break;
      default:
        color = AppColors.textSecondary;
        text = AppStrings.past.tr();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: AppText(
        text: text,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildCountdownBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            text: "${AppStrings.startsIn.tr()} ",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          AppText(
            text: "2h 30m",
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.neonBlue,
          ),
        ],
      ),
    );
  }
}
