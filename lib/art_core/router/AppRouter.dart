import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/features/onboarding/presentation/onboarding_screen.dart';
import 'package:playspot/features/splash/presentation/splash_screen.dart';
class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouterKeys.onboarding,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: RouterKeys.splash,
        name: RouterKeys.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouterKeys.onboarding,
        name: RouterKeys.onboarding,
        builder: (context, state) => const OnBoardingPage(),
      ),
      // ),
      // GoRoute(
      //   path: RouterKeys.login,
      //   builder: (context, state) => const LoginScreen(),
      // ),
      // GoRoute(
      //   path: RouterKeys.home,
      //   builder: (context, state) => const HomeScreen(),
      // ),
    ],
  );
}

