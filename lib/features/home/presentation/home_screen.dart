import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/text_field/home_search_bar.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/widgets/home_header.dart';
import 'package:playspot/art_core/widgets/shimmer/lounge_card_shimmer.dart';
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
    
    // Get saved address or default
    final savedAddress = pref.getValue('CURRENT_ADDRESS');
    currentLocation = savedAddress.isNotEmpty 
        ? savedAddress 
        : "Searching location...";
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
              AppColors.neonBlue.withOpacity(0.03),
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
                          previous.status != current.status,
                      builder: (context, state) {
                        return HomeHeader(
                          userName: userName,
                          currentLocation: currentLocation,
                          cities: state.availableCities,
                          selectedCity: state.selectedCity,
                          onCitySelected: (city) =>
                              context.read<HomeCubit>().selectCity(city),
                        );
                      },
                    ),
                  ),
                  /*bottom: PreferredSize(
                    preferredSize: Size.fromHeight(16.h),
                    child: HomeSearchBar(
                      readOnly: true,
                      onTap: () {
                        context.pushNamed(RouterKeys.search);
                      },
                    ),
                  ),*/
                ),
                SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                const SliverSectionHeader(
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
                mainAxisExtent: 250.h,
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
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text("No lounges found in this area", style: TextStyle(color: Colors.white)),
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
              mainAxisExtent: 240.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return LoungeCard(
                lounge: lounges[index],
                onTap: () {
                  context.pushNamed(
                    RouterKeys.loungeDetails,
                    extra: lounges[index],
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
