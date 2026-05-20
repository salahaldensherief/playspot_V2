import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/extra_category_item.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/extra_row.dart';
import 'package:playspot/features/lounge_details/presentation/widgets/room_card.dart';
import '../data/extra_model.dart';
import '../../home/data/models/lounge_model.dart';
import '../data/room_model.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';

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
                _buildAppBar(context),
                _buildInfoSection(),
                _buildSectionTitle("Available Rooms"),
                _buildRoomsGrid(),
                _buildSectionTitle("Extras"),
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

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.h,
      pinned: true,
      backgroundColor: AppColors.scaffoldBackground,
      leading: Padding(
        padding: EdgeInsets.all(8.w),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
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
                    text: "Open ${lounge.opensAt} - ${lounge.closesAt}",
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
                  text: "${lounge.rating} · 124 reviews",
                  fontSize: 14.sp,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            AppText(
              text: "See Reviews →",
              fontSize: 14.sp,
              color: AppColors.neonBlue,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 16.h),
            const Divider(color: AppColors.borderDefault),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: AppText(
          text: title,
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildRoomsGrid() {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.rooms.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No rooms available",
                style: TextStyle(color: Colors.white),
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
              mainAxisExtent: 130.h,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => RoomCard(room: state.rooms[index]),
              childCount: state.rooms.length,
            ),
          ),
        );
      },
    );
  }
  Widget _buildExtrasList() {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        if (state.status == LoungeDetailsStatus.loading)
          return const SliverToBoxAdapter(child: SizedBox());

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
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          border: const Border(top: BorderSide(color: AppColors.borderDefault)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: "Price per hour",
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
                AppText(
                  text: "${lounge.pricePerHour.toInt()} EGP",
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: AppText(
                text: "Book a Room",
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
