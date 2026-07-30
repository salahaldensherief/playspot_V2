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
import 'package:playspot/art_core/widgets/text_field/home_search_bar.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/widgets/home_header.dart';
import 'package:playspot/art_core/widgets/shimmer/lounge_card_shimmer.dart';
import '../../../art_core/widgets/cards/lounge_card.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/di/modules/auth_module.dart';
import 'home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeView();
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final userName = sl<PreferenceManager>().fullName() ?? "User";
    final currentLocation = sl<PreferenceManager>().latitude().isNotEmpty
        ? "My Location"
        : "New Cairo, Cairo";

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<HomeCubit>().getHomeData(),
          color: AppColors.neonBlue,
          backgroundColor: AppColors.cardBackground,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
              backgroundColor: AppColors.scaffoldBackground,
              expandedHeight: 180.h,
              pinned: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(50.r),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(
                      userName: userName,
                      currentLocation: currentLocation,
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(16.h),
                child: HomeSearchBar(
                  readOnly: true,
                  onTap: () {
                    context.pushNamed(RouterKeys.search);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 16.h)),
            const SliverSectionHeader(
              title: AppStrings.topRated,
              seeAllText: AppStrings.seeAll,
              onSeeAllTap: null,
            ),
            const _LoungeList(isNearest: false),
            const SliverBottomSpacing(height: 24),
          ],
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

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              mainAxisExtent: 230.h,
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
