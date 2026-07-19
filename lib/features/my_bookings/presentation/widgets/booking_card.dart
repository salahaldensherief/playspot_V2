import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../data/models/booking_model.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const BookingCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = booking.status == 'upcoming';
    
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
              AppText(
                text: booking.loungeName,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              _buildStatusBadge(),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16.sp),
              SizedBox(width: 4.w),
              AppText(
                text: booking.loungeLocation,
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AppText(
            text: "${booking.roomName} · ${booking.controllersCount} Controllers · ${booking.screenSize}",
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: AppColors.neonBlue, size: 16.sp),
              SizedBox(width: 8.w),
              AppText(
                text: _formatDate(booking.date),
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
                text: _formatTime(booking.startTime),
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
                    content: const ButtonContent(label: "Get Directions"),
                    behavior: ButtonBehavior.tap(onTap: () {}),
                    buttonConfig: ButtonConfig(
                      height: 45.h,
                      borderRadius: 12.r,
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                AppButton(
                  content: const ButtonContent(

                      label: "Cancel",),
                  behavior: ButtonBehavior.tap(onTap: onCancel),
                  buttonConfig: ButtonConfig(
                    height: 45.h,
                    width: 100.w,
                    borderRadius: 12.r,
                    backgroundColor: AppColors.transparent,
                    borderColor: AppColors.danger.withOpacity(0.3),
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
        text = "Confirmed";
        break;
      case 'cancelled':
        color = AppColors.danger;
        text = "Cancelled";
        break;
      default:
        color = AppColors.textSecondary;
        text = "Past";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
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
            text: "Starts in ",
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

  String _formatDate(DateTime date) {
    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      return "Today, ${DateFormat('MMMM d').format(date)}";
    }
    return DateFormat('EEEE, MMMM d').format(date);
  }

  String _formatTime(String time) {
    if (!time.contains(':')) return time;
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final tod = TimeOfDay(hour: hour, minute: minute);
    
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return "$h:${tod.minute.toString().padLeft(2, '0')} $period";
  }
}
