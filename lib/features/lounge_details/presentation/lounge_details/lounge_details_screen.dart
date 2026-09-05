import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import 'package:playspot/art_core/widgets/layout/sliver_bottom_spacing.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_details_cubit.dart';
import 'lounge_details_state.dart';
import 'widgets/lounge_details_app_bar.dart';
import 'widgets/lounge_info_section.dart';
import 'widgets/lounge_closed_banner.dart';
import 'widgets/date_selection_section.dart';
import 'widgets/rooms_grid.dart';
import 'widgets/extras_list.dart';
import 'widgets/reviews_section.dart';
import 'widgets/lounge_details_bottom_bar.dart';
import 'widgets/space_type_selector.dart';

class LoungeDetailsScreen extends StatelessWidget {
  final LoungeModel lounge;
  final String? heroTag;

  const LoungeDetailsScreen({super.key, required this.lounge, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge != current.lounge,
                  builder: (context, state) {
                    return LoungeDetailsAppBar(
                        lounge: state.lounge ?? lounge, heroTag: heroTag);
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.lounge?.isOpen != current.lounge?.isOpen ||
                      previous.lounge?.isDiscountActive != current.lounge?.isDiscountActive,
                  builder: (context, state) {
                    final displayLounge = state.lounge ?? lounge;
                    
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (!displayLounge.isOpen) const LoungeClosedBanner(),
                          if (displayLounge.isDiscountActive)
                            _LoungeDiscountBanner(lounge: displayLounge),
                        ],
                      ),
                    );
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge != current.lounge,
                  builder: (context, state) {
                    return LoungeInfoSection(lounge: state.lounge ?? lounge);
                  },
                ),
                const SliverSectionHeader(title: AppStrings.selectDate),
                const DateSelectionSection(),
                const SliverToBoxAdapter(child: SpaceTypeSelector()),
                const SliverSectionHeader(
                    title: AppStrings.availableRooms),
                const RoomsGrid(),
                const SliverSectionHeader(title: AppStrings.extras),
                const ExtrasList(),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.lounge?.name != current.lounge?.name ||
                      previous.reviews != current.reviews,
                  builder: (context, state) {
                    return SliverSectionHeader(
                      title: AppStrings.reviews,
                      seeAllText: AppStrings.seeAll,
                      onSeeAllTap: () {
                        context.pushNamed(
                          RouterKeys.allReviews,
                          extra: {
                            'cubit': context.read<LoungeDetailsCubit>(),
                            'reviews': state.reviews,
                            'loungeName': state.lounge?.name ?? lounge.name,
                          },
                        );
                      },
                    );
                  },
                ),
                const ReviewsSection(),
                const SliverBottomSpacing(),
                const SliverSafeBottomSpacer(),
              ],
            ),
          ),
          LoungeDetailsBottomBar(lounge: lounge),
        ],
      ),
    );
  }
}

class _LoungeDiscountBanner extends StatelessWidget {
  final LoungeModel lounge;
  const _LoungeDiscountBanner({required this.lounge});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.9),
            const Color(0xFFFF8C00).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer, color: Colors.black, size: 20.sp),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: lounge.getDiscountTitle(isArabic) ??
                      AppStrings.directDiscountAvailable.tr(),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
                AppText(
                  text: AppStrings.getDiscountNow.tr(args: [lounge.discountPercentage.toString()]),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          if (lounge.discountPercentage > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: AppText(
                text: "-${lounge.discountPercentage}%",
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}
