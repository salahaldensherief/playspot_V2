import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/provider_scope.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/auth/presentation/banned_account_screen.dart';
import 'package:playspot/features/auth/presentation/sign_in/signin_screen.dart';
import 'package:playspot/features/auth/presentation/sign_up/signup_screen.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/onboarding/presentation/onboarding_screen.dart';
import 'package:playspot/features/profile/presentation/settings/notification_settings_cubit.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';
import 'package:playspot/features/splash/presentation/splash_screen.dart';
import 'package:playspot/art_core/widgets/layout/swipe_back_wrapper.dart';
import '../../core/di.dart';
import '../../core/services/deep_link_service.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/presentation/forgot_password/otp_verification_screen.dart';
import '../../features/auth/presentation/sign_in/signin_cubit.dart';
import '../../features/auth/presentation/sign_up/complete_profile_screen.dart';
import '../../features/auth/presentation/sign_up/signup_cubit.dart';
import '../../features/booking/data/models/booking_params.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/booking_cubit.dart';
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
import '../../features/profile/presentation/support/help_support_screen.dart';
import '../../features/profile/presentation/edit_profile/edit_profile_cubit.dart';
import '../../features/profile/presentation/edit_profile/edit_profile_screen.dart';
import '../../features/profile/presentation/profile/redeem_points_screen.dart';
import '../../features/profile/presentation/profile/points_history_screen.dart';
import '../../features/profile/presentation/profile/my_vouchers_screen.dart';
import '../../features/active_session/presentation/active_session_screen.dart';
import '../../features/active_session/presentation/active_session_cubit.dart';
import '../../features/active_session/presentation/active_session_state.dart';
import '../../features/lounge_details/presentation/lounge_details/room_details_screen.dart';
import '../../features/tournaments/presentation/tournaments_feed/tournaments_feed_cubit.dart';
import '../../features/tournaments/presentation/tournaments_feed/tournaments_feed_screen.dart';
import '../../features/tournaments/presentation/tournament_details/tournament_details_cubit.dart';
import '../../features/tournaments/presentation/tournament_details/tournament_details_screen.dart';
import '../../features/tournaments/presentation/live_match/tournament_match_cubit.dart';
import '../../features/tournaments/presentation/live_match/tournament_match_screen.dart';
import '../../features/tournaments/presentation/history/tournament_history_cubit.dart';
import '../../features/tournaments/presentation/history/tournament_history_screen.dart';
import '../../features/app_status/presentation/screens/maintenance_screen.dart';
import '../../features/app_status/presentation/screens/force_update_screen.dart';
import '../../features/app_status/domain/entities/app_status_entity.dart';
import '../../features/app_status/domain/entities/app_status_type.dart';
import '../../features/app_status/presentation/cubit/app_status_cubit.dart';
import '../../features/app_status/presentation/cubit/app_status_state.dart';
import '../../core/notifications/notification_router.dart';
import '../presentation/locale_cubit.dart';
import '../theme/app_colors.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  late final _AppRuntimeRefreshNotifier _runtimeRefreshNotifier;

  AppRouter() {
    _runtimeRefreshNotifier = _AppRuntimeRefreshNotifier(
      appStatusCubit: sl<AppStatusCubit>(),
      activeSessionCubit: sl<ActiveSessionCubit>(),
    );
    _setupNotificationHandler();
  }

  void _setupNotificationHandler() {
    NotificationRouter.configure((data) {
      final user = sl<AuthRepository>().getCurrentUser();
      if (user == null) {
        // Unauthenticated users cannot trigger private notification actions
        return false;
      }
      return NotificationRouter.registry.handleNotification(data);
    });
  }

  static const Set<String> _protectedRoutes = {
    RouterKeys.checkout,
    RouterKeys.booking,
    RouterKeys.myBookings,
    RouterKeys.bookingDetails,
    RouterKeys.editProfile,
    RouterKeys.favorites,
    RouterKeys.redeemPoints,
    RouterKeys.pointsHistory,
    RouterKeys.myVouchers,
    RouterKeys.notifications,
    RouterKeys.notificationSettings,
    RouterKeys.activeSession,
    RouterKeys.tournaments,
    RouterKeys.tournamentDetails,
    RouterKeys.tournamentMatch,
    RouterKeys.tournamentHistory,
  };

  static Page<T> _buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return MaterialPage<T>(
      key: state.pageKey,
      child: SwipeBackWrapper(child: child),
    );
  }

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouterKeys.splash,
    refreshListenable: _runtimeRefreshNotifier,
    debugLogDiagnostics: kDebugMode,
    extraCodec: const MyExtraCodec(),
    redirect: (context, state) {
      if (state.uri.queryParameters.containsKey('ref') ||
          state.uri.queryParameters.containsKey('referral') ||
          state.uri.queryParameters.containsKey('code') ||
          state.uri.queryParameters.containsKey('p_referral_code')) {
        try {
          sl<DeepLinkService>().handleIncomingUri(state.uri);
        } catch (e, stack) {
          AppLogger.error('DeepLink handling failed for URI: ${state.uri}', e, stack);
        }
      }

      final user = sl<AuthRepository>().getCurrentUser();
      final currentPath = state.uri.path;
      final currentName = state.name;

      final isAuthPath = currentPath == RouterKeys.splash ||
          currentPath == RouterKeys.onboarding ||
          currentPath == RouterKeys.signIn ||
          currentPath == RouterKeys.signUp ||
          currentPath == RouterKeys.verifySignupOTP ||
          currentPath == RouterKeys.completeProfile;

      if (user == null) {
        final isProtected = (currentName != null && _protectedRoutes.contains(currentName)) ||
            currentPath.startsWith('/booking-details') ||
            currentPath.startsWith('/tournaments/');
        if (isProtected) {
          return RouterKeys.signIn;
        }
        return null;
      }

      final isPhoneMissing = user.phone == null || user.phone!.trim().isEmpty;
      if (isPhoneMissing && !isAuthPath && currentPath != RouterKeys.bannedAccount) {
        return RouterKeys.completeProfile;
      }

      if (user.isBanned) {
        if (currentPath != RouterKeys.bannedAccount) {
          return RouterKeys.bannedAccount;
        }
        return null;
      }

      final appStatusState = sl<AppStatusCubit>().state;
      final appStatusType = appStatusState.statusType;

      if (appStatusType == AppStatusType.forceUpdate) {
        if (currentPath != RouterKeys.forceUpdate) {
          return RouterKeys.forceUpdate;
        }
        return null;
      }

      if (appStatusType == AppStatusType.maintenance) {
        if (currentPath != RouterKeys.maintenance) {
          return RouterKeys.maintenance;
        }
        return null;
      }

      if (appStatusType == AppStatusType.maintenanceRestricted) {
        final isNewBookingAttempt = currentName == RouterKeys.booking ||
            currentName == RouterKeys.checkout ||
            currentPath.startsWith('/booking') ||
            currentPath.startsWith('/checkout');

        if (isNewBookingAttempt) {
          return RouterKeys.home;
        }
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => sl<LocaleCubit>(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RouterKeys.bannedAccount,
            name: RouterKeys.bannedAccount,
            pageBuilder: (context, state) {
              final user = sl<AuthRepository>().getCurrentUser();
              return _buildPage(
                context: context,
                state: state,
                child: BannedAccountScreen(reason: user?.bannedReason),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.splash,
            name: RouterKeys.splash,
            pageBuilder: (context, state) => _buildPage(
              context: context,
              state: state,
              child: const SplashScreen(),
            ),
          ),
          GoRoute(
            path: RouterKeys.maintenance,
            name: RouterKeys.maintenance,
            pageBuilder: (context, state) => _buildPage(
              context: context,
              state: state,
              child: MaintenanceScreen(
                statusEntity: state.extra as AppStatusEntity? ??
                    sl<AppStatusCubit>().state.statusEntity,
              ),
            ),
          ),
          GoRoute(
            path: RouterKeys.forceUpdate,
            name: RouterKeys.forceUpdate,
            pageBuilder: (context, state) {
              final extra = state.extra;
              final globalState = sl<AppStatusCubit>().state;
              AppStatusEntity? entity = globalState.statusEntity;
              String version = globalState.currentAppVersion;
              if (extra is Map<String, dynamic>) {
                entity = extra['entity'] as AppStatusEntity? ?? entity;
                version = extra['version'] as String? ?? version;
              } else if (extra is AppStatusEntity) {
                entity = extra;
              }
              return _buildPage(
                context: context,
                state: state,
                child: ForceUpdateScreen(
                  statusEntity: entity,
                  currentVersion: version,
                ),
              );
            },
          ),
          GoRoute(
            path: RouterKeys.onboarding,
            name: RouterKeys.onboarding,
            pageBuilder: (context, state) => _buildPage(
              context: context,
              state: state,
              child: const OnBoardingPage(),
            ),
          ),
          ShellRoute(
            builder: (context, state, child) {
              return BlocProvider(
                create: (context) => sl<SignupCubit>(),
                child: child,
              );
            },
            routes: [
              GoRoute(
                path: RouterKeys.signUp,
                name: RouterKeys.signUp,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const SignUpScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.verifySignupOTP,
                name: RouterKeys.verifySignupOTP,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const OTPVerificationScreen(isSignUp: true),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouterKeys.signIn,
            name: RouterKeys.signIn,
            pageBuilder: (context, state) => _buildPage(
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
              final extra = state.extra;
              UserModel? userModel;
              String extraId = '';
              if (extra is UserModel) {
                userModel = extra;
                extraId = userModel.id;
              } else if (extra is String) {
                extraId = extra;
              }

              final currentUser = sl<AuthRepository>().getCurrentUser();
              final currentUserId = currentUser?.id ?? '';
              final userId = extraId.isNotEmpty ? extraId : currentUserId;
              final userToUse = userModel ?? currentUser;

              return _buildPage(
                context: context,
                state: state,
                child: BlocProvider(
                  create: (context) => sl<SignupCubit>(),
                  child: CompleteProfileScreen(userId: userId, initialUser: userToUse),
                ),
              );
            },
          ),

          // Authenticated ShellRoute - loaded only when user enters authenticated screens
          ShellRoute(
            builder: (context, state, child) {
              return AppProviderScope(
                providers: [
                  BlocProvider(create: (context) => sl<FavoritesCubit>()),
                  BlocProvider(create: (context) => sl<ProfileCubit>()),
                  BlocProvider(create: (context) => sl<NotificationsCubit>()),
                  BlocProvider.value(value: sl<ActiveSessionCubit>()),
                  BlocProvider(create: (context) => sl<MyBookingsCubit>()),
                ],
                child: child,
              );
            },
            routes: [
              // Routes that share Cubits in MainScreen
              ShellRoute(
                builder: (context, state, child) {
                  return BlocProvider(
                    create: (context) => sl<HomeCubit>(),
                    child: child,
                  );
                },
                routes: [
                  GoRoute(
                    path: RouterKeys.home,
                    name: RouterKeys.home,
                    pageBuilder: (context, state) {
                      final index = state.extra is int ? state.extra as int : 0;
                      return _buildPage(
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
                    pageBuilder: (context, state) => _buildPage(
                      context: context,
                      state: state,
                      child: const SearchScreen(),
                    ),
                  ),
                  GoRoute(
                    path: RouterKeys.myBookings,
                    name: RouterKeys.myBookings,
                    pageBuilder: (context, state) {
                      final extraMap = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                      final initialTab = extraMap?['initialTab'] as int? ??
                          (state.uri.queryParameters['tab'] != null ? int.tryParse(state.uri.queryParameters['tab']!) : null);
                      final highlightedId = extraMap?['highlightedBookingId'] as String? ?? state.uri.queryParameters['id'];
                      return _buildPage(
                        context: context,
                        state: state,
                        child: MyBookingsScreen(
                          highlightedBookingId: highlightedId,
                          initialTabIndex: initialTab,
                        ),
                      );
                    },
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

                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<LoungeDetailsCubit>(),
                      child: LoungeDetailsScreen(
                        lounge: lounge,
                        loungeId: loungeId,
                        heroTag: heroTag,
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
                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<LoungeDetailsCubit>(),
                      child: RoomDetailsScreen(roomId: roomId),
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.booking,
                name: RouterKeys.booking,
                redirect: (context, state) {
                  if (state.extra == null) return RouterKeys.home;
                  if (state.extra is! BookingDetailsParams && state.extra is! Map<String, dynamic>) {
                    return RouterKeys.home;
                  }
                  return null;
                },
                pageBuilder: (context, state) {
                  BookingDetailsParams? params;
                  if (state.extra is BookingDetailsParams) {
                    params = state.extra as BookingDetailsParams;
                  } else if (state.extra is Map<String, dynamic>) {
                    try {
                      params = BookingDetailsParams.fromMap(state.extra as Map<String, dynamic>);
                    } catch (e, stack) {
                      AppLogger.error('Failed to parse BookingDetailsParams from extra map', e, stack);
                    }
                  }

                  final bookingParams = params;
                  if (bookingParams == null) {
                    return _buildPage(
                      context: context,
                      state: state,
                      child: const Scaffold(
                        backgroundColor: AppColors.scaffoldBackground,
                        body: SizedBox.shrink(),
                      ),
                    );
                  }

                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<BookingCubit>(param1: bookingParams),
                      child: BookingScreen(params: bookingParams),
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.checkout,
                name: RouterKeys.checkout,
                redirect: (context, state) {
                  if (state.extra == null) return RouterKeys.home;
                  if (state.extra is! CheckoutParams && state.extra is! Map<String, dynamic>) {
                    return RouterKeys.home;
                  }
                  return null;
                },
                pageBuilder: (context, state) {
                  CheckoutParams? params;
                  if (state.extra is CheckoutParams) {
                    params = state.extra as CheckoutParams;
                  } else if (state.extra is Map<String, dynamic>) {
                    try {
                      params = CheckoutParams.fromMap(state.extra as Map<String, dynamic>);
                    } catch (e, stack) {
                      AppLogger.error('Failed to parse CheckoutParams from extra map', e, stack);
                    }
                  }

                  final checkoutParams = params;
                  if (checkoutParams == null) {
                    return _buildPage(
                      context: context,
                      state: state,
                      child: const Scaffold(
                        backgroundColor: AppColors.scaffoldBackground,
                        body: SizedBox.shrink(),
                      ),
                    );
                  }

                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<CheckoutCubit>(),
                      child: CheckoutScreen(params: checkoutParams),
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.editProfile,
                name: RouterKeys.editProfile,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: BlocProvider(
                    create: (context) => sl<EditProfileCubit>(),
                    child: const EditProfileScreen(),
                  ),
                ),
              ),
              GoRoute(
                path: RouterKeys.redeemPoints,
                name: RouterKeys.redeemPoints,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const RedeemPointsScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.pointsHistory,
                name: RouterKeys.pointsHistory,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const PointsHistoryScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.myVouchers,
                name: RouterKeys.myVouchers,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const MyVouchersScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.favorites,
                name: RouterKeys.favorites,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const FavoritesScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.notifications,
                name: RouterKeys.notifications,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const NotificationsScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.notificationSettings,
                name: RouterKeys.notificationSettings,
                pageBuilder: (context, state) => _buildPage(
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
                  final extra = state.extra is Map ? (state.extra as Map) : const {};
                  final rawReviews = extra['reviews'];
                  final List<ReviewModel> reviews = rawReviews is List
                      ? rawReviews.map((e) {
                          if (e is ReviewModel) return e;
                          if (e is Map<String, dynamic>) return ReviewModel.fromJson(e);
                          if (e is Map) return ReviewModel.fromJson(Map<String, dynamic>.from(e));
                          return null;
                        }).whereType<ReviewModel>().toList()
                      : <ReviewModel>[];
                  final loungeName = extra['loungeName']?.toString() ?? '';

                  return _buildPage(
                    context: context,
                    state: state,
                    child: AllReviewsScreen(
                      reviews: reviews,
                      loungeName: loungeName,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.termsAndConditions,
                name: RouterKeys.termsAndConditions,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const TermsAndConditionsScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.helpSupport,
                name: RouterKeys.helpSupport,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: const HelpSupportScreen(),
                ),
              ),
              GoRoute(
                path: RouterKeys.activeSession,
                name: RouterKeys.activeSession,
                pageBuilder: (context, state) {
                  String? bookingId;
                  int? extensionMinutes;
                  if (state.extra is String) {
                    bookingId = state.extra as String;
                  } else if (state.extra is Map<String, dynamic>) {
                    final map = state.extra as Map<String, dynamic>;
                    bookingId = map['booking_id']?.toString() ?? map['bookingId']?.toString();
                    extensionMinutes = int.tryParse(map['extension_minutes']?.toString() ?? map['extensionMinutes']?.toString() ?? '');
                  }
                  return _buildPage(
                    context: context,
                    state: state,
                    child: ActiveSessionScreen(bookingId: bookingId, extensionMinutes: extensionMinutes),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.bookingDetails,
                name: RouterKeys.bookingDetails,
                pageBuilder: (context, state) {
                  final bookingId = state.pathParameters['id'];
                  final extraMap = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  final initialTab = extraMap?['initialTab'] as int? ??
                      (state.uri.queryParameters['tab'] != null ? int.tryParse(state.uri.queryParameters['tab']!) : null);
                  return _buildPage(
                    context: context,
                    state: state,
                    child: MyBookingsScreen(
                      highlightedBookingId: bookingId,
                      initialTabIndex: initialTab,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.tournaments,
                name: RouterKeys.tournaments,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: BlocProvider(
                    create: (context) => sl<TournamentsFeedCubit>(),
                    child: const TournamentsFeedScreen(),
                  ),
                ),
              ),
              GoRoute(
                path: RouterKeys.tournamentDetails,
                name: RouterKeys.tournamentDetails,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<TournamentDetailsCubit>(),
                      child: TournamentDetailsScreen(tournamentId: id),
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.tournamentMatch,
                name: RouterKeys.tournamentMatch,
                pageBuilder: (context, state) {
                  final tournamentId = state.pathParameters['id'] ?? '';
                  final matchId = state.pathParameters['matchId'] ?? '';
                  return _buildPage(
                    context: context,
                    state: state,
                    child: BlocProvider(
                      create: (context) => sl<TournamentMatchCubit>(),
                      child: TournamentMatchScreen(
                        tournamentId: tournamentId,
                        matchId: matchId,
                      ),
                    ),
                  );
                },
              ),
              GoRoute(
                path: RouterKeys.tournamentHistory,
                name: RouterKeys.tournamentHistory,
                pageBuilder: (context, state) => _buildPage(
                  context: context,
                  state: state,
                  child: BlocProvider(
                    create: (context) => sl<TournamentHistoryCubit>(),
                    child: const TournamentHistoryScreen(),
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(AppStrings.pageNotFound.tr())),
    ),
  );
}

class MyExtraCodec extends Codec<Object?, Object?> {
  const MyExtraCodec();

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
    if (input is ReviewModel) {
      return {'__type': 'ReviewModel', ...input.toJson()};
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
          case 'ReviewModel':
            return ReviewModel.fromJson(map);
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


class _AppRuntimeRefreshNotifier extends ChangeNotifier {
  final AppStatusCubit appStatusCubit;
  final ActiveSessionCubit activeSessionCubit;

  late final StreamSubscription<AppStatusState> _appStatusSubscription;
  late final StreamSubscription<ActiveSessionState> _activeSessionSubscription;

  _AppRuntimeRefreshNotifier({
    required this.appStatusCubit,
    required this.activeSessionCubit,
  }) {
    _syncActiveSession(activeSessionCubit.state);

    _appStatusSubscription = appStatusCubit.stream.listen((_) {
      notifyListeners();
    });

    _activeSessionSubscription = activeSessionCubit.stream.listen((state) {
      _syncActiveSession(state);
      notifyListeners();
    });
  }

  void _syncActiveSession(ActiveSessionState state) {
    final session = state.session;
    final hasActiveSession =
        state.status == ActiveSessionStatus.loaded &&
        session != null &&
        session.status == 'in_progress';

    appStatusCubit.updateActiveSessionStatus(
      hasActiveSession: hasActiveSession,
    );
  }

  @override
  void dispose() {
    _appStatusSubscription.cancel();
    _activeSessionSubscription.cancel();
    super.dispose();
  }
}
