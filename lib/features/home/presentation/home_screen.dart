import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/time/app_clock.dart';
import 'package:playspot/art_core/widgets/layout/app_refresh_indicator.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/features/home/presentation/widgets/active_session_banner.dart';
import 'package:playspot/features/home/presentation/widgets/home_background.dart';
import 'package:playspot/features/home/presentation/widgets/home_browse_by_category_section.dart';
import 'package:playspot/features/home/presentation/widgets/home_lounge_list.dart';
import 'package:playspot/features/home/presentation/widgets/home_lounge_section_header.dart';
import 'package:playspot/features/home/presentation/widgets/home_sliver_app_bar.dart';
import 'package:playspot/features/home/presentation/widgets/promo_carousel.dart';
import 'package:playspot/features/notifications/presentation/notifications_cubit.dart';

class HomeScreen extends StatelessWidget {
  final bool isActive;

  const HomeScreen({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: isActive,
      child: AppClock(child: _HomeView(isActive: isActive)),
    );
  }
}

class _HomeView extends StatefulWidget {
  final bool isActive;

  const _HomeView({required this.isActive});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  late final String userName;
  late final String currentLocation;
  final ScrollController _scrollController = ScrollController();
  late final HomeCubit _homeCubit;
  bool _isLoadingMoreTriggered = false;
  bool _initialized = false;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _homeCubit = context.read<HomeCubit>();
    final pref = sl<PreferenceManager>();
    userName = pref.fullName() ?? "User";

    final savedAddress = pref.getValue('CURRENT_ADDRESS');
    currentLocation = savedAddress.isNotEmpty
        ? savedAddress
        : "Searching location...";

    _scrollController.addListener(_onScroll);

    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted && widget.isActive) {
          context.read<HomeCubit>().startLocationListening();
        }
      },
      onPause: () {
        if (mounted) {
          context.read<HomeCubit>().stopLocationListening();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _initializeHome();
    });
  }

  void _initializeHome() {
    if (_initialized) return;
    _initialized = true;
    _homeCubit.init();
    _homeCubit.startLocationListening();
    context.read<NotificationsCubit>().getNotifications(context.locale.languageCode);
  }

  @override
  void didUpdateWidget(covariant _HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      if (_initialized) {
        _homeCubit.startLocationListening();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) _initializeHome();
        });
      }
    } else {
      _homeCubit.stopLocationListening();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _homeCubit.stopLocationListening();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentPixels = _scrollController.position.pixels;

    if (maxScroll > 100 && currentPixels >= maxScroll - 200) {
      final state = context.read<HomeCubit>().state;
      final canLoadMore = !_isLoadingMoreTriggered &&
          !state.isLoungesLoading &&
          state.status != HomeStatus.loading &&
          state.status != HomeStatus.refreshing &&
          state.status != HomeStatus.loadingMore &&
          !state.hasReachedMax &&
          state.nearestLounges.isNotEmpty;

      if (canLoadMore) {
        _isLoadingMoreTriggered = true;
        context.read<HomeCubit>().loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.isLoungesLoading != current.isLoungesLoading,
      listener: (context, state) {
        if (state.status != HomeStatus.loadingMore) {
          _isLoadingMoreTriggered = false;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Stack(
          children: [
            const RepaintBoundary(child: HomeBackground()),
            SafeArea(
              child: AppRefreshIndicator(
                onRefresh: () => context.read<HomeCubit>().refreshHome(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    HomeSliverAppBar(
                      userName: userName,
                      currentLocation: currentLocation,
                    ),
                    const SliverToBoxAdapter(child: ActiveSessionBanner()),
                    const SliverToBoxAdapter(child: PromoCarousel()),
                    const HomeBrowseByCategorySection(),
                    const HomeLoungeSectionHeader(),
                    const HomeLoungeList(),
                    BlocBuilder<HomeCubit, HomeState>(
                      buildWhen: (previous, current) =>
                          previous.status != current.status,
                      builder: (context, state) {
                        if (state.status == HomeStatus.loadingMore) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: const Center(
                                child: AppLoader(
                                  size: 28,
                                  color: AppColors.neonBlue,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      },
                    ),
                    SliverBottomSpacing(height: 150.h),
                    const SliverSafeBottomSpacer(androidOnly: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
