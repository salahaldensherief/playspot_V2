import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/shimmer/extra_shimmer.dart';
import '../../../../art_core/widgets/layout/app_state_view.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'extra_category_item.dart';

class ExtrasList extends StatelessWidget {
  const ExtrasList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.extras != current.extras,
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ExtraShimmer(),
              childCount: 3,
            ),
          );
        }

        if (state.status == LoungeDetailsStatus.error) {
          return const SliverAppStateView(
            type: AppStateViewType.error,
            title: AppStrings.errorLoadingExtras,
          );
        }

        if (state.extras.isEmpty) {
          return const SliverAppStateView(
            title: AppStrings.noExtrasAvailable,
            icon: Icons.fastfood_outlined,
          );
        }

        final categories = state.extras.map((e) => e.category).toSet().toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ExtraCategoryItem(
              category: categories[index],
              items: state.extras
                  .where((e) => e.category == categories[index])
                  .toList(),
            ),
            childCount: categories.length,
          ),
        );
      },
    );
  }
}
