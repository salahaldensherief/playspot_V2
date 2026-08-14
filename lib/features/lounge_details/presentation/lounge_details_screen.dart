import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../art_core/router/router_keys.dart';
import '../../home/data/models/lounge_model.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';
import 'widgets/lounge_details_app_bar.dart';
import 'widgets/lounge_info_section.dart';
import 'widgets/lounge_closed_banner.dart';
import 'widgets/category_selector.dart';
import 'widgets/date_selection_section.dart';
import 'widgets/rooms_grid.dart';
import 'widgets/extras_list.dart';
import 'widgets/reviews_section.dart';
import 'widgets/lounge_details_bottom_bar.dart';
import 'widgets/space_type_selector.dart';

class LoungeDetailsScreen extends StatelessWidget {
  final LoungeModel lounge;
  final String? heroTag;

  const LoungeDetailsScreen({super.key, required this.lounge, this.heroTag});

  @override
  Widget build(BuildContext context) {
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge != current.lounge,
                  builder: (context, state) {
                    return LoungeDetailsAppBar(
                        lounge: state.lounge ?? lounge, heroTag: heroTag);
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge?.isOpen != current.lounge?.isOpen,
                  builder: (context, state) {
                    final displayLounge = state.lounge ?? lounge;
                    if (displayLounge.isOpen) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return const LoungeClosedBanner();
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge != current.lounge,
                  builder: (context, state) {
                    return LoungeInfoSection(lounge: state.lounge ?? lounge);
                  },
                ),
                const SliverSectionHeader(title: AppStrings.selectDate),
                const DateSelectionSection(),
                const CategorySelector(),
                const SliverSectionHeader(
                    title: AppStrings.availableRooms),
                const SliverToBoxAdapter(child: SpaceTypeSelector()),
                const RoomsGrid(),
                const SliverSectionHeader(title: AppStrings.extras),
                const ExtrasList(),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.lounge?.name != current.lounge?.name ||
                      previous.reviews != current.reviews,
                  builder: (context, state) {
                    return SliverSectionHeader(
                      title: AppStrings.reviews,
                      seeAllText: AppStrings.seeAll,
                      onSeeAllTap: () {
                        context.pushNamed(
                          RouterKeys.allReviews,
                          extra: {
                            'cubit': context.read<LoungeDetailsCubit>(),
                            'reviews': state.reviews,
                            'loungeName': state.lounge?.name ?? lounge.name,
                          },
                        );
                      },
                    );
                  },
                ),
                const ReviewsSection(),
                const SliverBottomSpacing(),
                const SliverSafeBottomSpacer(),
              ],
            ),
          ),
          LoungeDetailsBottomBar(lounge: lounge),
        ],
      ),
    );
  }
}
