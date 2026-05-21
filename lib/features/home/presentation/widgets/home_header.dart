import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String currentLocation;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: AppStrings.heyUser.tr(args: [userName]),
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            fontFamily: "Orbitron",
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                 Icons.location_on_outlined,
                  color: AppColors.neonBlue,
                 size: 16.sp,
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: currentLocation,
                  fontSize: 14.sp,
                  color: AppColors.white,
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 18.w,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
