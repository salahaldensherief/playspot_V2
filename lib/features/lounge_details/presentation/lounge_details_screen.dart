import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/layout/sliver_app_divider.dart';
import '../../home/data/models/lounge_model.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';
import 'widgets/lounge_details_app_bar.dart';
import 'widgets/lounge_info_section.dart';
import 'widgets/category_selector.dart';
import 'widgets/date_selection_section.dart';
import 'widgets/rooms_grid.dart';
import 'widgets/extras_list.dart';
import 'widgets/lounge_details_bottom_bar.dart';

class LoungeDetailsScreen extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeDetailsScreen({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          sl<LoungeDetailsCubit>()..getLoungeDetails(lounge.id),
      child: Scaffold(
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
                      LoungeDetailsAppBar(lounge: displayLounge),
                      LoungeInfoSection(lounge: displayLounge),
                      const CategorySelector(),
                      const SliverSectionHeader(title: AppStrings.selectDate),
                      const DateSelectionSection(),
                      const SliverAppDivider(verticalPadding: 8),
                      SliverSectionHeader(
                        title: state.selectedCategory
                      ),
                      const RoomsGrid(),
                      const SliverSectionHeader(title: AppStrings.extras),
                      const ExtrasList(),
                      const SliverBottomSpacing(),
                    ],
                  );
                },
              ),
            ),
            LoungeDetailsBottomBar(lounge: lounge),
          ],
        ),
    ),
  );
}
  }