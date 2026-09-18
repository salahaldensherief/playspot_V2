import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:playspot/art_core/widgets/layout/app_refresh_indicator.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
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

  LoungeModel _displayLounge(LoungeDetailsState state) => state.lounge ?? lounge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          AppRefreshIndicator(
            onRefresh: () async {
              await context
                  .read<LoungeDetailsCubit>()
                  .getLoungeDetails(lounge.id);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) => previous.lounge != current.lounge,
                  builder: (context, state) {
                    return LoungeDetailsAppBar(
                        lounge: _displayLounge(state), heroTag: heroTag);
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.lounge?.isOpen != current.lounge?.isOpen ||
                      previous.lounge?.isDiscountActive != current.lounge?.isDiscountActive,
                  builder: (context, state) {
                    final displayLounge = _displayLounge(state);
                    
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
                    return LoungeInfoSection(lounge: _displayLounge(state));
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.tournaments != current.tournaments ||
                      previous.status != current.status,
                  builder: (context, state) {
                    return SliverConditionalSection(
                      isVisible: state.tournaments.isNotEmpty,
                      title: AppStrings.tournaments,
                      content: _LoungeTournamentBanner(tournaments: state.tournaments),
                    );
                  },
                ),
                const SliverSectionHeader(title: AppStrings.selectDate),
                const DateSelectionSection(),
                const SliverToBoxAdapter(child: SpaceTypeSelector()),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.filteredRooms != current.filteredRooms ||
                      previous.isDateLoading != current.isDateLoading ||
                      previous.status != current.status,
                  builder: (context, state) {
                    return SliverConditionalSection(
                      isVisible: state.status == LoungeDetailsStatus.loading ||
                          state.isDateLoading ||
                          state.filteredRooms.isNotEmpty,
                      title: AppStrings.availableRooms,
                      content: const RoomsGrid(),
                    );
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.extras != current.extras ||
                      previous.status != current.status,
                  builder: (context, state) {
                    return SliverConditionalSection(
                      isVisible: state.status == LoungeDetailsStatus.loading ||
                          state.extras.isNotEmpty,
                      title: AppStrings.extras,
                      content: const ExtrasList(),
                    );
                  },
                ),
                BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                  buildWhen: (previous, current) =>
                      previous.lounge?.name != current.lounge?.name ||
                      previous.reviews != current.reviews ||
                      previous.status != current.status,
                  builder: (context, state) {
                    return SliverConditionalSection(
                      isVisible: state.status == LoungeDetailsStatus.loading ||
                          state.reviews.isNotEmpty,
                      title: AppStrings.reviews,
                      seeAllText: AppStrings.seeAll,
                      onSeeAllTap: () {
                        context.pushNamed(
                          RouterKeys.allReviews,
                          extra: {
                            'reviews': state.reviews,
                            'loungeName': _displayLounge(state).name,
                          },
                        );
                      },
                      content: const ReviewsSection(),
                    );
                  },
                ),
                const SliverBottomSpacing(height: 100),
                const SliverSafeBottomSpacer(extraPadding: 40),
              ],
            ),
          ),
          LoungeDetailsBottomBar(lounge: lounge),
        ],
      ),
    );
  }
}

class SliverConditionalSection extends StatelessWidget {
  final bool isVisible;
  final String title;
  final String? seeAllText;
  final VoidCallback? onSeeAllTap;
  final Widget content;

  const SliverConditionalSection({
    super.key,
    required this.isVisible,
    required this.title,
    this.seeAllText,
    this.onSeeAllTap,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverSectionHeader(
          title: title,
          seeAllText: seeAllText,
          onSeeAllTap: onSeeAllTap,
        ),
        content,
      ],
    );
  }
}

class _LoungeDiscountBanner extends StatefulWidget {
  final LoungeModel lounge;
  const _LoungeDiscountBanner({required this.lounge});

  @override
  State<_LoungeDiscountBanner> createState() => _LoungeDiscountBannerState();
}

class _LoungeDiscountBannerState extends State<_LoungeDiscountBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.022).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withValues(alpha: 0.95),
              AppColors.warning.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
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
                    text: widget.lounge.getDiscountTitle(isArabic) ??
                        AppStrings.directDiscountAvailable.tr(),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  AppText(
                    text: AppStrings.getDiscountNow.tr(args: [widget.lounge.discountPercentage.toString()]),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            if (widget.lounge.discountPercentage > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: AppText(
                  text: "-${widget.lounge.discountPercentage}%",
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoungeTournamentBanner extends StatelessWidget {
  final List<TournamentEntity> tournaments;

  const _LoungeTournamentBanner({required this.tournaments});

  @override
  Widget build(BuildContext context) {
    final itemWidth = tournaments.length == 1 ? 340.w : 280.w;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: SizedBox(
          height: 135.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return Container(
                width: itemWidth,
                margin: EdgeInsetsDirectional.only(end: index == tournaments.length - 1 ? 0 : 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        context.pushNamed(
                          RouterKeys.tournamentDetails,
                          pathParameters: {'id': tournament.id},
                        );
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: tournament.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppColors.tournamentHeaderBg,
                                      child: const Center(
                                        child: AppLoader(
                                          size: 24,
                                          strokeWidth: 2,
                                          color: AppColors.neonBlue,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.tournamentPromoGradient,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.tournamentPromoGradient,
                                    ),
                                  ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.black.withValues(alpha: 0.4),
                                    AppColors.black.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonBlue.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.5)),
                                      ),
                                      child: AppText(
                                        text: tournament.game.toUpperCase(),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Orbitron',
                                        color: AppColors.neonBlue,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: AppText(
                                        text: "${tournament.entryFee.toStringAsFixed(0)} ${AppStrings.egp.tr()}",
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      text: tournament.title,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Orbitron',
                                      color: Colors.white,
                                      maxLines: 1,
                                    ),
                                    4.verticalSpace,
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12.sp, color: AppColors.neonBlue),
                                        4.horizontalSpace,
                                        AppText(
                                          text: tournament.startDate != null ? DateFormat('dd/MM/yyyy · hh:mm a').format(tournament.startDate!) : '',
                                          fontSize: 11.sp,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
