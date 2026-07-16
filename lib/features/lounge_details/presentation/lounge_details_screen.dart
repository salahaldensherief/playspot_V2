import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/widgets/layout/section_header.dart';
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
            CustomScrollView(
              slivers: [
                LoungeDetailsAppBar(lounge: lounge),
                LoungeInfoSection(lounge: lounge),
                const CategorySelector(),
                const DateSelectionSection(),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (prev, curr) =>
                      prev.availableRoomsCount != curr.availableRoomsCount,
                  builder: (context, state) {
                    return SliverToBoxAdapter(
                      child: SectionHeader(
                        title: state.selectedCategory,
                      ),
                    );
                  },
                ),
                const RoomsGrid(),
                const SliverToBoxAdapter(
                  child: SectionHeader(title: AppStrings.extras),
                ),
                const ExtrasList(),
                SliverToBoxAdapter(child: SizedBox(height: 120.h)),
              ],
            ),
            LoungeDetailsBottomBar(lounge: lounge),
          ],
        ),
      ),
    );
  }
}
