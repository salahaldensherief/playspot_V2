import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomFeatureItem extends StatelessWidget {
  final String feature;
  const RoomFeatureItem({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 10.sp, color: AppColors.success.withOpacity(0.6)),
          6.horizontalSpace,
          AppText(
              text: feature,
              fontSize: 10.sp,
              color: Colors.white70,
              fontWeight: FontWeight.w500),
        ],
      ),
    );
  }
}
