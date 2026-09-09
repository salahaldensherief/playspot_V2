import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/buttons/language_toggle_widget.dart';

class AuthAppBar extends StatelessWidget {
  const AuthAppBar({
    super.key,
    this.title,
    this.subTitle,
    this.showBackButton = true,
    this.showLanguageToggle = true,
  });

  final String? title;
  final String? subTitle;
  final bool showBackButton;
  final bool showLanguageToggle;

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && context.canPop();

    return SizedBox(
      height: 70.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Glow
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: -70.h,
            start: 150.w,
            end: 0,
            child: Center(
              child: Container(
                width: 350.w,
                height: 300.h,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue,
                      blurRadius: 100.r,
                      spreadRadius: 30.r,
                    ),
                    BoxShadow(
                      color: AppColors.neonPurple,
                      blurRadius: 100.r,
                      spreadRadius: 30.r,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Back Button on start side
          if (canPop)
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 16.h,
              start: 16.w,
              child: const BackButtonWidget(),
            ),

          // Language Toggle on end side
          if (showLanguageToggle)
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 16.h,
              end: 16.w,
              child: const LanguageToggleWidget(isCompact: true),
            ),

          // Title & Subtitle Section
          Positioned.directional(
            textDirection: Directionality.of(context),
            bottom: -180.h,
            start: 0,
            end: 0,
            child: Column(
              children: [
                Text(
                  (title ?? 'Create an Account').tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subTitle != null) ...[
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      subTitle!.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
