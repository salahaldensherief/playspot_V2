import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/cards/lounge_card.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'favorites_cubit.dart';
import 'favorites_state.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesCubit>().getFavoriteLounges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "My Favorites",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<FavoritesCubit>().getFavoriteLounges(),
        color: AppColors.neonBlue,
        backgroundColor: AppColors.cardBackground,
        child: BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, state) {
            if (state.status == FavoritesStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == FavoritesStatus.failure) {
              return AppStateView.error(
                title: state.errorMessage ?? "Error loading favorites",
                onRetry: () =>
                    context.read<FavoritesCubit>().getFavoriteLounges(),
              );
            }

            if (state.favoriteLounges.isEmpty) {
              return AppStateView.empty(
                title: "No favorites yet",
                subtitle: "Your favorite lounges will appear here",
                icon: Icons.favorite_border,
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(AppSizes.screenPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSizes.w12,
                      mainAxisSpacing: AppSizes.s12,
                      mainAxisExtent: 260.h,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lounge = state.favoriteLounges[index];
                        final heroTag = 'lounge_${lounge.id}_fav';
                        return LoungeCard(
                          lounge: lounge,
                          heroTag: heroTag,
                          onTap: () {
                            context.pushNamed(
                              RouterKeys.loungeDetails,
                              extra: {
                                'lounge': lounge,
                                'heroTag': heroTag,
                              },
                            );
                          },
                        );
                      },
                      childCount: state.favoriteLounges.length,
                    ),
                  ),
                ),
                const SliverBottomSpacing(),
                const SliverSafeBottomSpacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}
