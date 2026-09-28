import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/features/home/presentation/widgets/activity_categories.dart';

class HomeBrowseByCategorySection extends StatelessWidget {
  const HomeBrowseByCategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.categories != current.categories ||
          previous.isCategoriesLoading != current.isCategoriesLoading,
      builder: (context, state) {
        if (state.categories.isEmpty && !state.isCategoriesLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverSectionHeader(title: AppStrings.browseByCategory),
            const SliverToBoxAdapter(child: ActivityCategories()),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
          ],
        );
      },
    );
  }
}
