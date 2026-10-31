import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'reviews_section.dart';

class LoungeReviewsSection extends StatelessWidget {
  const LoungeReviewsSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) =>
            a.reviews != b.reviews ||
            a.lounge?.name != b.lounge?.name ||
            a.status != b.status,
        builder: (context, state) {
          if (state.reviews.isEmpty &&
              state.status != LoungeDetailsStatus.loading) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverMainAxisGroup(
            slivers: [
              SliverSectionHeader(
                compact: true,
                title: AppStrings.reviews,
                seeAllText: AppStrings.seeAll,
                onSeeAllTap: () => context.pushNamed(
                  RouterKeys.allReviews,
                  extra: {
                    'reviews': state.reviews,
                    'loungeName': state.lounge?.name ?? '',
                  },
                ),
              ),
              const ReviewsSection(),
            ],
          );
        },
      );
}
