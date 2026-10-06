import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/app_refresh_indicator.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import 'lounge_overview_section.dart';
import 'lounge_details_app_bar.dart';
import 'lounge_tournaments_section.dart';
import 'date_selection_section.dart';
import 'category_selector.dart';
import 'space_type_selector.dart';
import 'rooms_grid.dart';
import 'lounge_extras_section.dart';
import 'lounge_reviews_section.dart';
import 'lounge_booking_action.dart';

class LoungeDetailsContent extends StatelessWidget {
  final LoungeModel? initialLounge;
  final String? loungeId;
  final String? heroTag;
  final ScrollController controller;
  const LoungeDetailsContent({
    super.key,
    this.initialLounge,
    this.loungeId,
    this.heroTag,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AppRefreshIndicator(
        onRefresh: () => context.read<LoungeDetailsCubit>().getLoungeDetails(
          context.read<LoungeDetailsCubit>().state.lounge?.id ??
              initialLounge?.id ??
              loungeId ??
              '',
        ),
        child: CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LoungeDetailsAppBar(lounge: initialLounge, heroTag: heroTag),
            LoungeOverviewSection(
              initialLounge: initialLounge,
              loungeId: loungeId,
              heroTag: heroTag,
            ),
            const LoungeTournamentsSection(),
            const SliverSectionHeader(title: AppStrings.selectDate),
            const DateSelectionSection(),
            const SliverSectionHeader(title: AppStrings.filterByActivity),
            const CategorySelector(),
            const SliverToBoxAdapter(child: SpaceTypeSelector()),
            const SliverSectionHeader(title: 'lounge_rooms_section'),
            const RoomsGrid(),
            const LoungeExtrasSection(),
            const LoungeReviewsSection(),
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    56 * MediaQuery.textScalerOf(context).scale(1) +
                    40 +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
      LoungeBookingAction(initialLounge: initialLounge),
    ],
  );
}
