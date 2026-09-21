import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class TournamentInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Widget? customValueWidget;

  const TournamentInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.customValueWidget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.neonBlue;

    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      borderRadius: 12.r,
      blur: 8,
      borderColor: AppColors.borderSubtle,
      color: AppColors.mutedBackground.withValues(alpha: 0.35),
      child: Row(
        children: [
          GlassContainer(
            padding: EdgeInsets.all(8.w),
            borderRadius: 10.r,
            blur: 6,
            borderColor: effectiveIconColor.withValues(alpha: 0.3),
            color: effectiveIconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: effectiveIconColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: label,
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                ),
                SizedBox(height: 2.h),
                customValueWidget ??
                    AppText(
                      text: value,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
