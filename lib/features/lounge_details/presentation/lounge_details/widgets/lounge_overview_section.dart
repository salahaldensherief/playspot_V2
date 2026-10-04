import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/shimmer/room_card_shimmer.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'lounge_closed_banner.dart';
import 'lounge_discount_banner.dart';
import 'lounge_info_section.dart';
import 'lounge_technical_issue_banner.dart';

class LoungeOverviewSection extends StatelessWidget {
  final LoungeModel? initialLounge;
  final String? loungeId;
  final String? heroTag;
  const LoungeOverviewSection({
    super.key,
    this.initialLounge,
    this.loungeId,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) =>
            a.lounge != b.lounge ||
            a.operatingStatus != b.operatingStatus ||
            (a.lounge == null && a.status != b.status),
        builder: (context, state) {
          final lounge = state.lounge ?? initialLounge;
          if (lounge == null) {
            if (state.status == LoungeDetailsStatus.error) {
              return SliverAppStateView(
                type: AppStateViewType.error,
                title: AppStrings.errorLoadingRooms,
                onRetry: () =>
                    context.read<LoungeDetailsCubit>().initById(loungeId ?? ''),
              );
            }
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: RoomCardShimmer(),
              ),
            );
          }

          final opStatus = state.operatingStatus;
          final isTechnicalIssue = opStatus?.isTechnicalIssue ?? false;
          final isClosed = opStatus != null
              ? (!opStatus.isOpen && !isTechnicalIssue)
              : !lounge.isOpen;

          return SliverMainAxisGroup(
            slivers: [
              if (isTechnicalIssue)
                SliverToBoxAdapter(
                  child: LoungeTechnicalIssueBanner(
                    contactPhone: opStatus?.contactPhone,
                  ),
                )
              else if (isClosed)
                const SliverToBoxAdapter(child: LoungeClosedBanner()),
              if (lounge.isDiscountActive)
                SliverToBoxAdapter(child: LoungeDiscountBanner(lounge: lounge)),
              LoungeInfoSection(lounge: lounge),
            ],
          );
        },
      );
}
