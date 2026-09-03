import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/auth/presentation/sign_in/signin_screen.dart';
import 'package:playspot/features/auth/presentation/sign_up/signup_screen.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/onboarding/presentation/onboarding_screen.dart';
import 'package:playspot/features/profile/presentation/settings/notification_settings_cubit.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';
import 'package:playspot/features/splash/presentation/splash_screen.dart';
import '../../core/di.dart';
import '../../features/auth/presentation/forgot_password/forgot_password_cubit.dart';
import '../../features/auth/presentation/forgot_password/forgot_password_screen.dart';
import '../../features/auth/presentation/forgot_password/otp_verification_screen.dart';
import '../../features/auth/presentation/forgot_password/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in/signin_cubit.dart';
import '../../features/auth/presentation/sign_up/complete_profile_screen.dart';
import '../../features/auth/presentation/sign_up/signup_cubit.dart';
import '../../features/booking/data/models/booking_params.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/booking_cubit.dart';
import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/checkout/presentation/checkout_cubit.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/favorites/presentation/favorites_cubit.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_cubit.dart';
import '../../features/lounge_details/data/models/review_model.dart';
import '../../features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import '../../features/lounge_details/presentation/lounge_details/lounge_details_screen.dart';
import '../../features/main/presentation/main_screen.dart';
import '../../features/my_bookings/presentation/my_bookings_cubit.dart';
import '../../features/my_bookings/presentation/my_bookings_screen.dart';
import '../../features/lounge_details/presentation/reviews/all_reviews_screen.dart';
import '../../features/notifications/presentation/notifications_cubit.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/settings/notification_settings_screen.dart';
import '../../features/profile/presentation/profile/profile_cubit.dart';
import '../../features/profile/presentation/legal/terms_and_conditions_screen.dart';
import '../../features/profile/presentation/edit_profile/edit_profile_cubit.dart';
import '../../features/profile/presentation/edit_profile/edit_profile_screen.dart';
import '../../features/profile/presentation/profile/redeem_points_screen.dart';
import '../../features/profile/presentation/profile/my_vouchers_screen.dart';
import '../../features/active_session/presentation/active_session_screen.dart';
import '../../features/active_session/presentation/active_session_cubit.dart';
import '../../features/lounge_details/presentation/lounge_details/room_details_screen.dart';
import 'package:flutter/services.dart';
import '../../core/notifications/notification_router.dart';
import '../presentation/locale_cubit.dart';
import '../theme/app_colors.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  AppRouter() {
    _setupNotificationHandler();
  }

  void _setupNotificationHandler() {
    NotificationRouter.configure((data) {
      final typeStr =
          (data['type'] ?? data['notification_type'] ?? '').toString().toLowerCase();

      final bookingId = _extractKey(data, [
        'booking_id',
        'bookingId',
        'id',
        'target_id',
        'reference_id',
        'entity_id',
      ]);

      final code = _extractKey(data, [
        'code',
        'promo_code',
        'promoCode',
        'coupon',
      ]);

      if (typeStr.contains('booking') || bookingId.isNotEmpty) {
        if (bookingId.isNotEmpty) {
          router.pushNamed(
            RouterKeys.bookingDetails,
            pathParameters: {'id': bookingId},
          );
        } else {
          router.goNamed(RouterKeys.myBookings);
        }
        return true;
      }

      if (typeStr.contains('offer') ||
          typeStr.contains('promo') ||
          code.isNotEmpty) {
        router.pushNamed(RouterKeys.myVouchers);
        if (code.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: code));
        }
        return true;
      }

      if (typeStr.contains('loyalty')) {
        router.goNamed(RouterKeys.home, extra: 2);
        return true;
      }

      if (typeStr.contains('active_session') || typeStr.contains('session')) {
        router.pushNamed(RouterKeys.activeSession);
        return true;
      }

      return false;
    });
  }

  static String _extractKey(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'null') {
        return val;
      }
    }
    return '';
  }

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
    extraCodec: const _MyExtraCodec(),
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => sl<LocaleCubit>(),
            child: BlocProvider(
              create: (context) => sl<FavoritesCubit>()..getFavoriteIds(),
              child: BlocProvider(
                create: (context) => sl<ProfileCubit>()..getUserData(),
                child: BlocProvider(
                  create: (context) => sl<NotificationsCubit>(),
                  child: BlocProvider(
                    create: (context) => sl<ActiveSessionCubit>()..loadActiveSession(),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
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
              child: BlocProvider(
                create: (context) => sl<SignupCubit>(),
                child: const SignUpScreen(),
              ),
            ),
          ),
          GoRoute(
            path: RouterKeys.signIn,
            name: RouterKeys.signIn,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: BlocProvider(
                create: (context) => sl<SignInCubit>(),
                child: const SignInScreen(),
              ),
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
                child: userId.isEmpty
                    ? const SignInScreen()
                    : BlocProvider(
                        create: (context) => sl<SignupCubit>()..setUserId(userId),
                        child: CompleteProfileScreen(userId: userId),
                      ),
              );
            },
          ),

          // Routes that share Cubits in MainScreen
          ShellRoute(
            builder: (context, state, child) {
              return BlocProvider(
                create: (context) => sl<HomeCubit>()..getHomeData(),
                child: BlocProvider(
                  create: (context) => sl<MyBookingsCubit>()..getMyBookings(),
                  child: child,
                ),
              );
            },
            routes: [
              GoRoute(
                path: RouterKeys.home,
                name: RouterKeys.home,
                pageBuilder: (context, state) {
                  final index = state.extra is int ? state.extra as int : 0;
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: MainScreen(
                      key: ValueKey(index),
                      initialIndex: index,
                    ),
                  );
                },
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
              GoRoute(
                path: RouterKeys.myBookings,
                name: RouterKeys.myBookings,
                pageBuilder: (context, state) => _buildPageWithTransition(
                  context: context,
                  state: state,
                  child: const MyBookingsScreen(),
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
              LoungeModel? lounge;
              String? loungeId;
              String? heroTag;

              if (state.extra is LoungeModel) {
                lounge = state.extra as LoungeModel;
              } else if (state.extra is Map<String, dynamic>) {
                final map = state.extra as Map<String, dynamic>;
                lounge = map['lounge'] as LoungeModel?;
                loungeId = map['loungeId'] as String?;
                heroTag = map['heroTag'] as String?;
              }

              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider(
                  create: (context) {
                    final cubit = sl<LoungeDetailsCubit>();
                    if (lounge != null) {
                      cubit.init(lounge);
                    } else if (loungeId != null) {
                      cubit.initById(loungeId);
                    }
                    return cubit;
                  },
                  child: lounge != null 
                    ? LoungeDetailsScreen(lounge: lounge, heroTag: heroTag)
                    : BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                        builder: (context, state) {
                          if (state.lounge != null) {
                            return LoungeDetailsScreen(lounge: state.lounge!, heroTag: heroTag);
                          }
                          return const Scaffold(
                            backgroundColor: AppColors.scaffoldBackground,
                            body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
                          );
                        },
                      ),
                ),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.roomDetails,
            name: RouterKeys.roomDetails,
            pageBuilder: (context, state) {
              final roomId = state.pathParameters['roomId'] ?? '';
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: RoomDetailsScreen(roomId: roomId),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.booking,
            name: RouterKeys.booking,
            pageBuilder: (context, state) {
              final params = state.extra is BookingDetailsParams
                  ? state.extra as BookingDetailsParams
                  : BookingDetailsParams.fromMap(state.extra as Map<String, dynamic>);

              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider(
                  create: (context) => BookingCubit(
                    sl<BookingRepository>(),
                    params,
                  ),
                  child: BookingScreen(params: params),
                ),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.checkout,
            name: RouterKeys.checkout,
            pageBuilder: (context, state) {
              final params = state.extra is CheckoutParams
                  ? state.extra as CheckoutParams
                  : CheckoutParams.fromMap(state.extra as Map<String, dynamic>);

              return _buildPageWithTransition(
                context: context,
                state: state,
                child: BlocProvider(
                  create: (context) => sl<CheckoutCubit>(),
                  child: CheckoutScreen(params: params),
                ),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.editProfile,
            name: RouterKeys.editProfile,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: BlocProvider(
                create: (context) => sl<EditProfileCubit>()..init(),
                child: const EditProfileScreen(),
              ),
            ),
          ),
          GoRoute(
            path: RouterKeys.redeemPoints,
            name: RouterKeys.redeemPoints,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const RedeemPointsScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.myVouchers,
            name: RouterKeys.myVouchers,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const MyVouchersScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.favorites,
            name: RouterKeys.favorites,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const FavoritesScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.notifications,
            name: RouterKeys.notifications,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.notificationSettings,
            name: RouterKeys.notificationSettings,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: BlocProvider(
                create: (context) => sl<NotificationSettingsCubit>(),
                child: const NotificationSettingsScreen(),
              ),
            ),
          ),
          GoRoute(
            path: RouterKeys.allReviews,
            name: RouterKeys.allReviews,
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: AllReviewsScreen(
                  reviews: extra['reviews'] as List<ReviewModel>,
                  loungeName: extra['loungeName'] as String,
                ),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.termsAndConditions,
            name: RouterKeys.termsAndConditions,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const TermsAndConditionsScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.activeSession,
            name: RouterKeys.activeSession,
            pageBuilder: (context, state) {
              String? bookingId;
              if (state.extra is String) {
                bookingId = state.extra as String;
              } else if (state.extra is Map<String, dynamic>) {
                bookingId = (state.extra as Map<String, dynamic>)['booking_id']?.toString();
              }
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: ActiveSessionScreen(bookingId: bookingId),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.bookingDetails,
            name: RouterKeys.bookingDetails,
            pageBuilder: (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const MyBookingsScreen(), // Fallback to MyBookings
            ),
          )
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
}

class _MyExtraCodec extends Codec<Object?, Object?> {
  const _MyExtraCodec();

  @override
  Converter<Object?, Object?> get decoder => const _MyExtraDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _MyExtraEncoder();
}

class _MyExtraEncoder extends Converter<Object?, Object?> {
  const _MyExtraEncoder();

  @override
  Object? convert(Object? input) {
    if (input is BookingDetailsParams) {
      return {'__type': 'BookingDetailsParams', ...input.toJson()};
    }
    if (input is CheckoutParams) {
      return {'__type': 'CheckoutParams', ...input.toJson()};
    }
    if (input is LoungeModel) {
      return {'__type': 'LoungeModel', ...input.toJson()};
    }
    if (input is RoomModel) {
      return {'__type': 'RoomModel', ...input.toJson()};
    }
    if (input is DateTime) {
      return {'__type': 'DateTime', 'value': input.toIso8601String()};
    }
    if (input is TimeOfDay) {
      return {'__type': 'TimeOfDay', 'hour': input.hour, 'minute': input.minute};
    }
    if (input is Map<String, dynamic>) {
      return input.map((key, value) => MapEntry(key, convert(value)));
    }
    if (input is List<dynamic>) {
      return input.map(convert).toList();
    }
    return input;
  }
}

class _MyExtraDecoder extends Converter<Object?, Object?> {
  const _MyExtraDecoder();

  @override
  Object? convert(Object? input) {
    if (input is Map<Object?, Object?>) {
      final map = input.cast<String, dynamic>();
      if (map.containsKey('__type')) {
        switch (map['__type']) {
          case 'BookingDetailsParams':
            return BookingDetailsParams.fromJson(map);
          case 'CheckoutParams':
            return CheckoutParams.fromJson(map);
          case 'LoungeModel':
            return LoungeModel.fromJson(map);
          case 'RoomModel':
            return RoomModel.fromJson(map);
          case 'DateTime':
            return DateTime.parse(map['value']);
          case 'TimeOfDay':
            return TimeOfDay(hour: map['hour'], minute: map['minute']);
        }
      }
      return map.map((key, value) => MapEntry(key, convert(value)));
    }
    if (input is List<dynamic>) {
      return input.map(convert).toList();
    }
    return input;
  }
}
