import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/widgets/home_header.dart';
import 'package:playspot/features/home/presentation/widgets/promo_carousel.dart';
import 'package:playspot/features/home/presentation/widgets/activity_categories.dart';
import 'package:playspot/art_core/widgets/shimmer/lounge_card_shimmer.dart';
import 'package:playspot/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../art_core/widgets/cards/lounge_card.dart';
import '../../../art_core/widgets/text/app_text.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../data/models/lounge_model.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final pref = sl<PreferenceManager>();
    userName = pref.fullName() ?? "User";

    final savedAddress = pref.getValue('CURRENT_ADDRESS');
    currentLocation = savedAddress.isNotEmpty
        ? savedAddress
        : "Searching location...";

    _scrollController.addListener(_onScroll);

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
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HomeCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          // Background decoration - wrapped in RepaintBoundary to avoid repainting on scroll
          const RepaintBoundary(child: _HomeBackground()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<HomeCubit>().getHomeData(),
              color: AppColors.neonBlue,
              backgroundColor: AppColors.cardBackground,
              child: CustomScrollView(
                controller: _scrollController,
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
                            previous.availableCities !=
                                current.availableCities ||
                            previous.selectedCity != current.selectedCity ||
                            previous.currentAddress != current.currentAddress ||
                            previous.pointsBalance != current.pointsBalance ||
                            (previous.status == HomeStatus.initial &&
                                current.status == HomeStatus.loading),
                        builder: (context, state) {
                          return HomeHeader(
                            userName: userName,
                            currentLocation:
                                state.currentAddress ?? currentLocation,
                            cities: state.availableCities,
                            selectedCity: state.selectedCity,
                            pointsBalance: state.pointsBalance,
                            onCitySelected: (city) =>
                                context.read<HomeCubit>().selectCity(city),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: PromoCarousel()),
                  24.verticalSpace.toSliver,
                  const SliverSectionHeader(title: AppStrings.browseByCategory),
                  const SliverToBoxAdapter(child: ActivityCategories()),
                  16.verticalSpace.toSliver,
                  const _LoungeSectionHeader(),
                  _LoungeList(),
                  BlocBuilder<HomeCubit, HomeState>(
                    buildWhen: (previous, current) =>
                        previous.status != current.status,
                    builder: (context, state) {
                      if (state.status == HomeStatus.loadingMore) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.neonBlue,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),
                  SliverBottomSpacing(height: 120.h),
                  const SliverSafeBottomSpacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoungeSectionHeader extends StatelessWidget {
  const _LoungeSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _SortToggle(),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.sortType != current.sortType,
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SortItem(
                  label: AppStrings.nearest.tr(),
                  icon: Icons.location_on_outlined,
                  isSelected: state.sortType == LoungeSortType.nearest,
                  onTap: () => context.read<HomeCubit>().changeSortType(
                    LoungeSortType.nearest,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _SortItem(
                  label: AppStrings.topRated.tr(),
                  icon: Icons.star_outline_rounded,
                  isSelected: state.sortType == LoungeSortType.topRated,
                  onTap: () => context.read<HomeCubit>().changeSortType(
                    LoungeSortType.topRated,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SortItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected
                  ? AppColors.black
                  : AppColors.textSecondary.withOpacity(0.6),
            ),
            SizedBox(width: 8.w),
            AppText(
              text: label,
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AppColors.black : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoungeList extends StatelessWidget {
  const _LoungeList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.nearestLounges != current.nearestLounges ||
          previous.sortType != current.sortType,
      builder: (context, state) {
        if (state.status == HomeStatus.loading &&
            state.nearestLounges.isEmpty) {
          return SliverPadding(
            padding: 16.horizontalPadding,
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

        final lounges = state.nearestLounges;

        if (lounges.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: 32.allPadding,
                child: Text(
                  AppStrings.noLoungesFound.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: 16.horizontalPadding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              mainAxisExtent: 235.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final lounge = lounges[index];
              final heroTag = 'lounge_${lounge.id}_main';
              return LoungeCard(
                lounge: lounge,
                heroTag: heroTag,
                onTap: () {
                  context.pushNamed(
                    RouterKeys.loungeDetails,
                    extra: {'lounge': lounge, 'heroTag': heroTag},
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

extension on Widget {
  SliverToBoxAdapter get toSliver => SliverToBoxAdapter(child: this);
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
