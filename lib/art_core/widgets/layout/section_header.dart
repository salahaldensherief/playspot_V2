import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllTap;
  final String? seeAllText;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAllTap,
    this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: 16.horizontalPadding + 12.verticalPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(
            text: title.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          if (onSeeAllTap != null)
            GestureDetector(
              onTap: onSeeAllTap,
              child: Row(
                children: [
                  AppText(
                    text: (seeAllText ?? "See all").tr(),
                    fontSize: 14.sp,
                    color: AppColors.neonBlue,
                  ),
                  4.horizontalSpace,
                  Icon(Icons.arrow_forward_ios, size: 12.sp, color: AppColors.neonBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
