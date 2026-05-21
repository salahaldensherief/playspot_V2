import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/auth/presetation/signin/signin_screen.dart';
import 'package:playspot/features/auth/presetation/signup/signup_screen.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/room_model.dart';
import 'package:playspot/features/onboarding/presentation/onboarding_screen.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';
import 'package:playspot/features/splash/presentation/splash_screen.dart';

import '../../core/di.dart';
import '../../features/auth/presetation/forgot_password/forgot_password_cubit.dart';
import '../../features/auth/presetation/forgot_password/forgot_password_screen.dart';
import '../../features/auth/presetation/forgot_password/otp_verification_screen.dart';
import '../../features/auth/presetation/forgot_password/reset_password_screen.dart';
import '../../features/auth/presetation/signup/complete_profile.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/home/presentation/home_cubit.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lounge_details/presentation/lounge_details_screen.dart';
import '../../features/main/presentation/main_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouterKeys.splash,
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
      GoRoute(
        path: RouterKeys.signUp,
        name: RouterKeys.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouterKeys.signIn,
        name: RouterKeys.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        name: RouterKeys.completeProfile,
        path: RouterKeys.completeProfile,
        builder: (context, state) {
          final userId = state.extra as String? ?? '';
          if (userId.isEmpty) {
            return const SignInScreen();
          }
          return CompleteProfileScreen(userId: userId);
        },
      ),

      // Routes that share HomeCubit
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => sl<HomeCubit>()..getHomeData(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RouterKeys.home,
            name: RouterKeys.home,
            builder: (context, state) => const MainScreen(),
          ),
          GoRoute(
            path: RouterKeys.search,
            name: RouterKeys.search,
            builder: (context, state) => const SearchScreen(),
          ),
        ],
      ),

      // Forgot password flow
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => sl<ForgotPasswordCubit>(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RouterKeys.forgotPassword,
            name: RouterKeys.forgotPassword,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: RouterKeys.verifyOTP,
            name: RouterKeys.verifyOTP,
            builder: (context, state) => const OTPVerificationScreen(),
          ),
          GoRoute(
            path: RouterKeys.resetPassword,
            name: RouterKeys.resetPassword,
            builder: (context, state) => const ResetPasswordScreen(),
          ),
        ],
      ),

      GoRoute(
        path: RouterKeys.loungeDetails,
        name: RouterKeys.loungeDetails,
        builder: (context, state) {
          final lounge = state.extra as LoungeModel;
          return LoungeDetailsScreen(lounge: lounge);
        },
      ),
      GoRoute(
        path: RouterKeys.booking,
        name: RouterKeys.booking,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final lounge = extra['lounge'] as LoungeModel;
          final room = extra['room'] as RoomModel;
          final initialDate = extra['selectedDate'] as DateTime?;
          return BookingScreen(
            lounge: lounge,
            room: room,
            initialDate: initialDate,
          );
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
}
