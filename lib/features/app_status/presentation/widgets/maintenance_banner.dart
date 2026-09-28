import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../art_core/app_strings.dart';

class MaintenanceBanner extends StatelessWidget {
  final String? customMessage;

  const MaintenanceBanner({
    super.key,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage?.isNotEmpty == true
        ? customMessage!
        : AppStrings.maintenanceActiveSessionNotice.tr();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF9800).withValues(alpha: 0.6),
            width: 1.w,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9800).withValues(alpha: 0.2),
            ),
            child: Icon(
              TablerIcons.alert_triangle,
              color: const Color(0xFFFF9800),
              size: 20.r,
            ),
          ),
          12.horizontalSpace,
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: const Color(0xFFFF9800),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
