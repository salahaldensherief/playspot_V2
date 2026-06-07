import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/extra_category_item.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/extra_row.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/room_card.dart';
import 'package:playspot/art_core/widgets/shimmer/extra_shimmer.dart';
import 'package:playspot/art_core/widgets/shimmer/room_card_shimmer.dart';
import '../../../art_core/router/router_keys.dart';
import '../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../booking/presentation/widgets/date_selector.dart';
import '../data/extra_model.dart';
import '../../home/data/models/lounge_model.dart';
import '../data/room_model.dart';
import 'package:playspot/art_core/widgets/layout/app_divider.dart';
import 'package:playspot/art_core/widgets/layout/section_header.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';

class LoungeDetailsScreen extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeDetailsScreen({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    print("LoungeDetailsScreen: Building for lounge ID => '${lounge.id}'");
    return BlocProvider(
      create: (context) =>
          sl<LoungeDetailsCubit>()..getLoungeDetails(lounge.id),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                _buildAppBar(context),
                _buildInfoSection(),
                _buildCategorySelector(),
                _buildDateSelectionSection(),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (prev, curr) =>
                      prev.availableRoomsCount != curr.availableRoomsCount,
                  builder: (context, state) {
                    return SliverToBoxAdapter(
                      child: SectionHeader(
                        title: "${state.selectedCategory} — select a unit",
                      ),
                    );
                  },
                ),
                _buildRoomsGrid(),
                SliverToBoxAdapter(
                  child: SectionHeader(title: AppStrings.extras.tr()),
                ),
                _buildExtrasList(),
                SliverToBoxAdapter(child: SizedBox(height: 120.h)),
              ],
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'name': 'PS5 Rooms', 'icon': Icons.videogame_asset_outlined},
      {'name': 'Simulator', 'icon': Icons.speed},
      {'name': 'Billiard', 'icon': Icons.sports_baseball_rounded},
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 60.h,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          builder: (context, state) {
            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = state.selectedCategory == cat['name'];

                return GestureDetector(
                  onTap: () => context
                      .read<LoungeDetailsCubit>()
                      .setCategory(cat['name'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonBlue.withOpacity(0.05)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(25.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.borderDefault,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 18.sp,
                          color: isSelected
                              ? AppColors.neonBlue
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          text: cat['name'] as String,
                          fontSize: 14.sp,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.neonBlue
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.h,
      pinned: true,
      backgroundColor: AppColors.scaffoldBackground,
      leading: Padding(padding: EdgeInsets.all(8.w), child: BackButtonWidget()),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: lounge.imageUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.scaffoldBackground.withOpacity(0.8),
                    AppColors.scaffoldBackground,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20.h,
              left: 16.w,
              right: 16.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: lounge.name,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text: lounge.location ?? "",
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 8.h),
                  AppText(
                    text:
                        "${AppStrings.openHours.tr()} ${_formatTime(lounge.opensAt)} - ${_formatTime(lounge.closesAt)}",
                    fontSize: 14.sp,
                    color: AppColors.neonBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || !time.contains(':')) return time ?? "";
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final timeOfDay = TimeOfDay(hour: hour, minute: minute);

      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final hourOfPeriod = timeOfDay.hourOfPeriod == 0
          ? 12
          : timeOfDay.hourOfPeriod;

      return "$hourOfPeriod $period";
    } catch (e) {
      return time;
    }
  }

  Widget _buildInfoSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      color: index < 4
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: "${lounge.rating} · 124 ${AppStrings.reviews.tr()}",
                  fontSize: 14.sp,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            AppText(
              text: AppStrings.seeReviews.tr(),
              fontSize: 14.sp,
              color: AppColors.neonBlue,
              fontWeight: FontWeight.bold,
            ),
            const AppDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectionSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: AppStrings.selectDate.tr()),
          BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
            builder: (context, state) {
              return DateSelector(
                selectedDate: state.selectedDate ?? DateTime.now(),
                onDateSelected: (date) =>
                    context.read<LoungeDetailsCubit>().selectDate(date),
              );
            },
          ),
          SizedBox(height: 16.h),
           Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: AppDivider(verticalPadding: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsGrid() {
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
          if (state.selectedCategory == 'Billiard') {
            return r.type.toLowerCase().contains('ps5') ||
                r.type.isEmpty ||
                r.type == 'Standard';
          }
          return r.type.toLowerCase().contains(
                state.selectedCategory.toLowerCase().split(' ').first,
              );
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
              mainAxisExtent: 160.h, // Increased height for new RoomCard design
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

  Widget _buildExtrasList() {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ExtraShimmer(),
              childCount: 3,
            ),
          );
        }

        if (state.status == LoungeDetailsStatus.error)
          return const SliverToBoxAdapter(
            child: Center(
              child: Text(
                "Error loading extras",
                style: TextStyle(color: Colors.red),
              ),
            ),
          );

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

  Widget _buildBottomBar() {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final isRoomSelected = state.selectedRoomId != null;
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              border: const Border(
                top: BorderSide(color: AppColors.borderDefault),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
              child: AppButton(
                content: ButtonContent(
                  body: AppText(
                    fontFamily: 'Orbitron',
                    textAlign: TextAlign.center,
                    text: AppStrings.bookARoom.tr(),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isRoomSelected ? AppColors.black : AppColors.white,
                  ),
                ),
                behavior: ButtonBehavior.tap(
                  isEnabled: isRoomSelected,
                  onTap: isRoomSelected
                      ? () {
                          final selectedRoom = state.rooms.firstWhere(
                            (r) => r.id == state.selectedRoomId,
                          );
                          final selectedExtras = state.selectedExtras.entries.map((entry) {
                            final extra = state.extras.firstWhere((e) => e.id == entry.key);
                            return {
                              'id': extra.id,
                              'name': extra.name,
                              'price': extra.price,
                              'quantity': entry.value,
                            };
                          }).toList();

                          context.pushNamed(
                            RouterKeys.booking,
                            extra: {
                              'lounge': lounge,
                              'room': selectedRoom,
                              'selectedDate':
                                  state.selectedDate ?? DateTime.now(),
                              'extras': selectedExtras,
                            },
                          );
                        }
                      : null,
                ),
                buttonConfig: ButtonConfig(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  glowColor: const Color(0xFF00D4FF),
                  borderRadius: 15.r,
                  width: 340.w,
                  height: 50.h,
                  backgroundColor: isRoomSelected
                      ? AppColors.neonBlue
                      : AppColors.cardBackground,
                  borderColor: isRoomSelected
                      ? AppColors.neonBlue
                      : AppColors.borderDefault,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
