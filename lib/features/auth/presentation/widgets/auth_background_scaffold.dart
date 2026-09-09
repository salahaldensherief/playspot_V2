import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';

class AuthBackgroundScaffold extends StatelessWidget {
  final Widget child;
  final Widget? appBar;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;

  const AuthBackgroundScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.footer,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          Positioned(
            top: -60.h,
            right: -40.w,
            child: _buildNeonOrb(
              color: AppColors.neonBlue.withValues(alpha: 0.22),
              size: 240.r,
            ),
          ),
          Positioned(
            bottom: 120.h,
            left: -50.w,
            child: _buildNeonOrb(
              color: AppColors.neonPurple.withValues(alpha: 0.20),
              size: 260.r,
            ),
          ),
          Positioned(
            top: 280.h,
            right: -30.w,
            child: _buildNeonOrb(
              color: AppColors.neonBlue.withValues(alpha: 0.12),
              size: 180.r,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (appBar != null) appBar!,
                  SizedBox(height: 12.h),
                  Padding(
                    padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w),
                    child: GlassContainer(
                      borderRadius: 24.r,
                      blur: 16,
                      borderOpacity: 0.12,
                      borderColor: AppColors.primary.withValues(alpha: 0.3),
                      color: AppColors.cardBackground.withValues(alpha: 0.55),
                      padding: EdgeInsets.all(20.r),
                      shadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.4),
                          blurRadius: 20.r,
                          spreadRadius: 2.r,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.neonBlue.withValues(alpha: 0.05),
                          blurRadius: 30.r,
                          spreadRadius: 1.r,
                        ),
                      ],
                      child: child,
                    ),
                  ),
                  if (footer != null) ...[
                    SizedBox(height: 20.h),
                    footer!,
                  ],
                  SizedBox(height: 16.h),
                  const SafeBottomSpacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonOrb({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.transparent),
        ),
      ),
    );
  }
}
