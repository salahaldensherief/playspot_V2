import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/logo/logo_widget.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import '../../../art_core/theme/app_colors.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/services/location_service.dart';

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

    _handleInitialization();
  }

  Future<void> _handleInitialization() async {
    final locationFuture = _fetchUserLocation();
    final delayFuture = Future.delayed(const Duration(seconds: 3));

    await Future.wait([locationFuture, delayFuture]);

    if (!mounted) return;

    final authRepo = sl<AuthRepository>();
    final profileRepo = sl<ProfileRepository>();

    var user = authRepo.getCurrentUser();

    if (user != null) {
      try {
        final result = await profileRepo.getUserProfile();
        result.fold((_) {}, (fetchedUser) {
          user = fetchedUser;
        });
      } catch (_) {}

      final phone = user?.phone;
      final isPhoneMissing = phone == null || phone.trim().isEmpty;

      if (!mounted) return;

      if (isPhoneMissing) {
        context.goNamed(
          RouterKeys.completeProfile,
          extra: user?.id ?? '',
        );
      } else {
        context.goNamed(RouterKeys.home);
      }
    } else {
      context.goNamed(RouterKeys.onboarding);
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      final locationService = sl<LocationService>();
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        final pref = sl<PreferenceManager>();
        await pref.saveLatitude(position.latitude);
        await pref.saveLongitude(position.longitude);
        
        final address = await locationService.getAddressFromLatLng(
          position.latitude,
          position.longitude,
        );
        if (address != null) {
          await pref.saveValue('CURRENT_ADDRESS', address);
        }
      }
    } catch (e) {
      debugPrint("SPLASH: Location fetch failed: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
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
              8.verticalSpace,
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  "Book, Play & Win",
                  style: TextStyle(
                    shadows: [
                      Shadow(
                        color: AppColors.neonBlue50,
                        blurRadius: 8.r,
                        offset: const Offset(0, 0),
                      ),
                    ],
                    color: AppColors.primary,
                    fontSize: 18.sp,
                    fontFamily: "Orbitron",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
