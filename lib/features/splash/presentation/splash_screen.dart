import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/logo/logo_widget.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/data/repos/auth_repos.dart';
import '../../../art_core/theme/app_colors.dart';
import '../../../core/cache/preference_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    _startNavigation();
  }

  void _startNavigation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      final user = sl<AuthRepository>().getCurrentUser();
      if (user != null) {
        // Ensure name is cached if user session is active
        sl<PreferenceManager>().saveFullName(user.name);
        sl<PreferenceManager>().saveUserId(user.id);
        sl<PreferenceManager>().saveIsLoggedIn(true);

        context.goNamed(RouterKeys.home);
      } else {
        context.goNamed(RouterKeys.onboarding);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Center(
                child: LogoWidget(
                  animate: true,
                  color: AppColors.primary,
                  fontSize: 50.w,
                  width: 40.w,
                  height: 40.h,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                AppStrings.bookPlayWin.tr(),
                style: TextStyle(
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withOpacity(0.6),
                      blurRadius: 8.r,
                      offset: Offset(0, 0.h),
                    ),
                  ],
                  color: AppColors.primary,
                  fontSize: 18.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
