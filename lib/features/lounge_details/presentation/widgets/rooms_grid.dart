import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/shimmer/room_card_shimmer.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'room_card.dart';

class RoomsGrid extends StatelessWidget {
  const RoomsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading) {
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
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
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                "Error loading rooms",
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (state.rooms.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppStrings.noRoomsAvailable.tr(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final filteredRooms = state.rooms.where((r) {
          final category = state.selectedCategory;
          final roomActivities = r.activityNames.map((a) => a.toLowerCase()).toList();
          
          final isPS5Category = category == AppStrings.ps5Rooms;
          final isSimulatorCategory = category == AppStrings.simulator;
          final isBilliardCategory = category == AppStrings.billiard;

          final isSimulatorRoom = roomActivities.any((a) => a.contains('simulator') || a.contains('racing') || a.contains('speed'));
          final isBilliardRoom = roomActivities.any((a) => a.contains('billiard') || a.contains('pool') || a.contains('snooker'));
          final isPS5Room = roomActivities.any((a) => a.contains('ps') || a.contains('playstation') || a.contains('console'));

          if (isSimulatorCategory) return isSimulatorRoom;
          if (isBilliardCategory) return isBilliardRoom;
          
          if (isPS5Category) {
            return isPS5Room || (!isSimulatorRoom && !isBilliardRoom);
          }
          
          return roomActivities.any((a) => a.contains(category.toLowerCase().split(' ').first));
        }).toList();

        if (filteredRooms.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppText(
                text: "No units found for this category",
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              mainAxisExtent: 180.h, 
            ),
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
