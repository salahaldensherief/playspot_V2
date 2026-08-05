import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/layout/sliver_app_divider.dart';
import '../../../art_core/router/router_keys.dart';
import '../../home/data/models/lounge_model.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';
import 'widgets/lounge_details_app_bar.dart';
import 'widgets/lounge_info_section.dart';
import 'widgets/category_selector.dart';
import 'widgets/date_selection_section.dart';
import 'widgets/rooms_grid.dart';
import 'widgets/extras_list.dart';
import 'widgets/reviews_section.dart';
import 'widgets/lounge_details_bottom_bar.dart';

class LoungeDetailsScreen extends StatelessWidget {
  final LoungeModel lounge;
  final String? heroTag;

  const LoungeDetailsScreen({super.key, required this.lounge, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          sl<LoungeDetailsCubit>()..init(lounge),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await context
                      .read<LoungeDetailsCubit>()
                      .getLoungeDetails(lounge.id);
                },
                color: AppColors.neonBlue,
                backgroundColor: AppColors.cardBackground,
                child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  builder: (context, state) {
                    final displayLounge = state.lounge ?? lounge;
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        LoungeDetailsAppBar(lounge: displayLounge, heroTag: heroTag),
                        LoungeInfoSection(lounge: displayLounge),
                        const SliverSectionHeader(title: AppStrings.selectDate),
                        const DateSelectionSection(),
                        const CategorySelector(),
                        const SliverSectionHeader(title: AppStrings.availableRooms),
                        const RoomsGrid(),
                        const SliverSectionHeader(title: AppStrings.extras),
                        const ExtrasList(),
                      SliverSectionHeader(
                        title: AppStrings.reviews,
                        seeAllText: AppStrings.seeAll,
                        onSeeAllTap: () {
                          context.pushNamed(
                            RouterKeys.allReviews,
                            extra: {
                              'cubit': context.read<LoungeDetailsCubit>(),
                              'reviews': state.reviews,
                              'loungeName': displayLounge.name,
                            },
                          );
                        },
                      ),
                      const ReviewsSection(),
                        const SliverBottomSpacing(),
                      ],
                    );
                  },
                ),
              ),
              LoungeDetailsBottomBar(lounge: lounge),
            ],
          ),
        );
      }),
    );
  }
}
