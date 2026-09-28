import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/logo/logo_widget.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/app_status/presentation/cubit/app_status_cubit.dart';
import 'package:playspot/features/app_status/domain/entities/app_status_type.dart';
import 'package:playspot/features/app_status/presentation/widgets/soft_update_dialog.dart';

import '../../../art_core/theme/app_colors.dart';
import '../../../core/cache/caching_key.dart';
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

    _safeRemoveNativeSplash();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnim = const AlwaysStoppedAnimation<double>(1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });

    _handleInitialization();
  }

  Future<void> _handleInitialization() async {
    unawaited(_fetchUserLocation());
    final minDisplayFuture = Future.delayed(const Duration(milliseconds: 300));

    final appStatusCubit = sl<AppStatusCubit>();
    final statusTypeFuture = appStatusCubit.checkAndListen();

    final results = await Future.wait([minDisplayFuture, statusTypeFuture]);
    final statusType = results[1] as AppStatusType;

    if (!mounted) return;

    if (statusType == AppStatusType.maintenance) {
      context.goNamed(RouterKeys.maintenance, extra: appStatusCubit.state.statusEntity);
      return;
    }

    if (statusType == AppStatusType.forceUpdate) {
      context.goNamed(
        RouterKeys.forceUpdate,
        extra: {
          'entity': appStatusCubit.state.statusEntity,
          'version': appStatusCubit.state.currentAppVersion,
        },
      );
      return;
    }

    if (statusType == AppStatusType.softUpdate) {
      await SoftUpdateDialog.show(
        context,
        statusEntity: appStatusCubit.state.statusEntity,
        onDismiss: () => appStatusCubit.dismissSoftUpdate(),
      );
    }

    if (!mounted) return;

    final authRepo = sl<AuthRepository>();
    final user = authRepo.getCurrentUser();
    final pref = sl<PreferenceManager>();

    if (user != null) {
      context.goNamed(RouterKeys.home);
    } else if (pref.isFirstTime()) {
      context.goNamed(RouterKeys.onboarding);
    } else {
      context.goNamed(RouterKeys.signIn);
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
          await pref.saveValue(CachingKey.CURRENT_ADDRESS, address);
        }
      }
    } catch (_) {}
  }

  void _safeRemoveNativeSplash() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = View.of(context).physicalSize;
      if (size.width > 0 && size.height > 0) {
        FlutterNativeSplash.remove();
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            FlutterNativeSplash.remove();
          }
        });
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
                    iconColor: AppColors.primary,
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
                  'BOOK • PLAY • WIN',
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
