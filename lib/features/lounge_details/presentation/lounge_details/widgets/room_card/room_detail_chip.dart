import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomDetailChip extends StatelessWidget {
  final String label;
  final Color themeColor;
  const RoomDetailChip({super.key, required this.label, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: themeColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 10.sp, color: themeColor.withOpacity(0.5)),
          6.horizontalSpace,
          AppText(text: label, fontSize: 10.sp, color: Colors.white70),
        ],
      ),
    );
  }
}
