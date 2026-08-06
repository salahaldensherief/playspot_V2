import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/widgets/home_header.dart';
import 'package:playspot/features/home/presentation/widgets/promo_carousel.dart';
import 'package:playspot/features/home/presentation/widgets/activity_categories.dart';
import 'package:playspot/art_core/widgets/shimmer/lounge_card_shimmer.dart';
import 'package:playspot/features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../../art_core/widgets/cards/lounge_card.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import 'home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeView();
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  late final String userName;
  late final String currentLocation;

  @override
  void initState() {
    super.initState();
    final pref = sl<PreferenceManager>();
    userName = pref.fullName() ?? "User";
    
    final savedAddress = pref.getValue('CURRENT_ADDRESS');
    currentLocation = savedAddress.isNotEmpty 
        ? savedAddress 
        : "Searching location...";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeCubit>().init();
        context.read<HomeCubit>().startLocationListening();
        final lang = context.locale.languageCode;
        context.read<NotificationsCubit>().getNotifications(lang);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [
              AppColors.neonBlue.withValues(alpha: 0.03),
              AppColors.scaffoldBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<HomeCubit>().getHomeData(),
            color: AppColors.neonBlue,
            backgroundColor: AppColors.cardBackground,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 150.h,
                  pinned: true,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: BlocBuilder<HomeCubit, HomeState>(
                      buildWhen: (previous, current) =>
                          previous.availableCities != current.availableCities ||
                          previous.selectedCity != current.selectedCity ||
                          previous.currentAddress != current.currentAddress ||
                          previous.pointsBalance != current.pointsBalance ||
                          (previous.status == HomeStatus.initial && current.status == HomeStatus.loading),
                      builder: (context, state) {
                        return HomeHeader(
                          userName: userName,
                          currentLocation: state.currentAddress ?? currentLocation,
                          cities: state.availableCities,
                          selectedCity: state.selectedCity,
                          pointsBalance: state.pointsBalance,
                          isLoading: state.status == HomeStatus.loading && state.availableCities.isEmpty,
                          onCitySelected: (city) =>
                              context.read<HomeCubit>().selectCity(city),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: PromoCarousel()),
                SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                const SliverSectionHeader(title: AppStrings.browseByCategory),
                const SliverToBoxAdapter(child: ActivityCategories()),
                SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                 SliverSectionHeader(
                  title: AppStrings.nearestLounges,
                  seeAllText: AppStrings.seeAll,
                  onSeeAllTap: null,
                ),
                const _LoungeList(isNearest: true),
                SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                 SliverSectionHeader(
                  title: AppStrings.topRated,
                  seeAllText: AppStrings.seeAll,
                  onSeeAllTap: null,
                ),
                const _LoungeList(isNearest: false),
                SliverBottomSpacing(height: 120.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoungeList extends StatelessWidget {
  final bool isNearest;
  const _LoungeList({required this.isNearest});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          (isNearest
              ? previous.nearestLounges != current.nearestLounges
              : previous.topRatedLounges != current.topRatedLounges),
      builder: (context, state) {
        if (state.status == HomeStatus.loading) {
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                mainAxisExtent: 260.h,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const LoungeCardShimmer(),
                childCount: 4,
              ),
            ),
          );
        }

        final lounges = isNearest
            ? state.nearestLounges
            : state.topRatedLounges;

        if (lounges.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(AppStrings.noLoungesFound.tr(), style: const TextStyle(color: Colors.white)),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              mainAxisExtent: 235.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final lounge = lounges[index];
              final heroTag = 'lounge_${lounge.id}_${isNearest ? "near" : "top"}';
              return LoungeCard(
                lounge: lounge,
                heroTag: heroTag,
                onTap: () {
                  debugPrint("HOME: Tapping on Lounge: ${lounge.name} (id: ${lounge.id})");
                  context.pushNamed(
                    RouterKeys.loungeDetails,
                    extra: {
                      'lounge': lounge,
                      'heroTag': heroTag,
                    },
                  );
                },
              );
            }, childCount: lounges.length),
          ),
        );
      },
    );
  }
}
