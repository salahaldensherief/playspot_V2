import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomSectionHeader extends StatelessWidget {
  final String title;
  final Color themeColor;
  const RoomSectionHeader({super.key, required this.title, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return AppText(
      text: title.toUpperCase(),
      fontSize: 8.sp,
      fontWeight: FontWeight.w900,
      color: themeColor.withOpacity(0.7),
      letterSpacing: 0.8,
    );
  }
}
