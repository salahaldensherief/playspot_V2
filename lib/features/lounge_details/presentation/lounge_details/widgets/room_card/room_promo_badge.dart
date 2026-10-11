import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomPromoBadge extends StatelessWidget {
  final String tag;
  const RoomPromoBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(16.r),
          bottomEnd: Radius.circular(8.r),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppText(
        text: tag.toUpperCase(),
        fontSize: 8.sp,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        letterSpacing: 0.5,
      ),
    );
  }
}
