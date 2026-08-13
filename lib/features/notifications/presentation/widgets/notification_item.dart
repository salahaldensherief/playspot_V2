import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import '../../data/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        child: GlassContainer(
          borderRadius: 20,
          borderOpacity: notification.isRead ? 0.05 : 0.2,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconContainer(),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AppText(
                              text: notification.title,
                              fontSize: 15.sp,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: const BoxDecoration(
                                color: AppColors.neonBlue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.neonBlue,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      AppText(
                        text: notification.body,
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      SizedBox(height: 10.h),
                      AppText(
                        text: DateFormat('dd MMM, hh:mm a').format(notification.createdAt),
                        fontSize: 11.sp,
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.booking:
        iconData = TablerIcons.calendar_check;
        if (notification.status == 'pending') {
          iconColor = AppColors.warning;
          iconData = TablerIcons.calendar_time;
        } else if (notification.status == 'upcoming') {
          iconColor = AppColors.success;
          iconData = TablerIcons.calendar_check;
        } else if (notification.status == 'cancelled') {
          iconColor = AppColors.danger;
          iconData = TablerIcons.calendar_x;
        } else {
          iconColor = AppColors.neonBlue;
        }
        break;
      case NotificationType.offer:
        iconData = TablerIcons.discount_2;
        iconColor = AppColors.neonPurple;
        break;
      case NotificationType.loyalty:
        iconData = TablerIcons.stars;
        iconColor = AppColors.warning;
        break;
      case NotificationType.system:
        iconData = TablerIcons.info_circle;
        iconColor = Colors.white;
        break;
    }

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 18.sp,
      ),
    );
  }
}
