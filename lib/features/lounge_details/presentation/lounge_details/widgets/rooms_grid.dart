import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/shimmer/room_card_shimmer.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'room_card/room_card.dart';

class RoomsGrid extends StatelessWidget {
  const RoomsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.rooms != current.rooms ||
          previous.selectedCategory != current.selectedCategory ||
          previous.selectedSpaceType != current.selectedSpaceType ||
          previous.deviceCategories != current.deviceCategories,
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading) {
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSizes.w12,
                mainAxisSpacing: AppSizes.s12,
                mainAxisExtent: 130.h,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const RoomCardShimmer(),
                childCount: 4,
              ),
            ),
          );
        }

        if (state.status == LoungeDetailsStatus.error) {
          return SliverAppStateView(
            type: AppStateViewType.error,
            title: AppStrings.errorLoadingRooms,
            onRetry: () => context
                .read<LoungeDetailsCubit>()
                .getLoungeDetails(state.lounge?.id ?? ""),
          );
        }

        if (state.rooms.isEmpty) {
          return SliverAppStateView(
            title: AppStrings.noRoomsAvailable,
            icon: Icons.meeting_room_outlined,
          );
        }

        final filteredRooms = state.filteredRooms;

        if (filteredRooms.isEmpty) {
          return SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: AppText(
                  text: "No rooms available for this category",
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => RoomCard(room: filteredRooms[index]),
              childCount: filteredRooms.length,
            ),
          ),
        );
      },
    );
  }
}
