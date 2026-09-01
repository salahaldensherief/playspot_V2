import 'package:easy_localization/easy_localization.dart';
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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8.r),
          topRight: context.locale.languageCode == 'ar' ? Radius.zero : Radius.circular(18.r),
          topLeft: context.locale.languageCode == 'ar' ? Radius.circular(18.r) : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.3),
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
