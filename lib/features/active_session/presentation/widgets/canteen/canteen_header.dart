import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class CanteenHeader extends StatelessWidget {
  final String? stationSubtitle;
  final VoidCallback onClose;

  const CanteenHeader({
    super.key,
    required this.stationSubtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 10.h),
        Center(
          child: Container(
            width: 44.w,
            height: 4.5.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 18.w),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.neonPurple, AppColors.neonBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            text: AppStrings.canteenMenu.tr(),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: 7.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: AppColors.neonPurple.withValues(
                                alpha: 0.6,
                              ),
                              width: 1,
                            ),
                          ),
                          child: const AppText(
                            text: "FUEL UP",
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neonPurple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    AppText(
                      text:
                          (stationSubtitle != null &&
                              stationSubtitle!.isNotEmpty)
                          ? stationSubtitle!
                          : AppStrings.orderExtras.tr(),
                      fontSize: 11.5.sp,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24.r),
                  onTap: onClose,
                  child: Container(
                    width: 48.w,
                    height: 48.w,
                    alignment: Alignment.center,
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
