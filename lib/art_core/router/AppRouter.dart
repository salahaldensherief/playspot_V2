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
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/home/presentation/home_cubit.dart';
import '../../features/lounge_details/presentation/lounge_details_screen.dart';
import '../../features/main/presentation/main_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static CustomTransitionPage _buildPageWithTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.00),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.linear,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouterKeys.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: RouterKeys.splash,
        name: RouterKeys.splash,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: RouterKeys.onboarding,
        name: RouterKeys.onboarding,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const OnBoardingPage(),
        ),
      ),
      GoRoute(
        path: RouterKeys.signUp,
        name: RouterKeys.signUp,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SignUpScreen(),
        ),
      ),
      GoRoute(
        path: RouterKeys.signIn,
        name: RouterKeys.signIn,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        name: RouterKeys.completeProfile,
        path: RouterKeys.completeProfile,
        pageBuilder: (context, state) {
          final userId = state.extra as String? ?? '';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: userId.isEmpty ? const SignInScreen() : CompleteProfileScreen(userId: userId),
          );
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
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const MainScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.search,
            name: RouterKeys.search,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const SearchScreen(),
            ),
          ),
        ],
      ),

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
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const ForgotPasswordScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.verifyOTP,
            name: RouterKeys.verifyOTP,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const OTPVerificationScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.resetPassword,
            name: RouterKeys.resetPassword,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const ResetPasswordScreen(),
            ),
          ),
        ],
      ),

      GoRoute(
        path: RouterKeys.loungeDetails,
        name: RouterKeys.loungeDetails,
        pageBuilder: (context, state) {
          final lounge = state.extra as LoungeModel;
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: LoungeDetailsScreen(lounge: lounge),
          );
        },
      ),
      GoRoute(
        path: RouterKeys.booking,
        name: RouterKeys.booking,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final lounge = extra['lounge'] as LoungeModel;
          final room = extra['room'] as RoomModel;
          final initialDate = extra['selectedDate'] as DateTime?;
          final extras = extra['extras'] as List<Map<String, dynamic>>? ?? [];
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: BookingScreen(
              lounge: lounge,
              room: room,
              initialDate: initialDate,
              addOns: extras,
            ),
          );
        },
      ),
      GoRoute(
        path: RouterKeys.checkout,
        name: RouterKeys.checkout,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: CheckoutScreen(
              lounge: extra['lounge'] as LoungeModel,
              room: extra['room'] as RoomModel,
              date: extra['date'] as DateTime,
              startTime: extra['startTime'] as TimeOfDay,
              duration: extra['duration'] as int,
              totalPrice: extra['totalPrice'] as double,
              addOns: extra['addOns'] as List<Map<String, dynamic>>,
            ),
          );
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
}
