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

class LoungeDetailsScreen extends StatefulWidget {
  final LoungeModel lounge;
  final String? heroTag;

  const LoungeDetailsScreen({super.key, required this.lounge, this.heroTag});

  @override
  State<LoungeDetailsScreen> createState() => _LoungeDetailsScreenState();
}

class _LoungeDetailsScreenState extends State<LoungeDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedRoom = context.read<LoungeDetailsCubit>().state.selectedRoomId;
      if (selectedRoom != null) {
        _scrollToRoomsSection();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRoomsSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          480.h,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  LoungeModel _displayLounge(LoungeDetailsState state) => state.lounge ?? widget.lounge;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoungeDetailsCubit, LoungeDetailsState>(
      listenWhen: (previous, current) =>
          previous.selectedRoomId != current.selectedRoomId && current.selectedRoomId != null,
      listener: (context, state) {
        if (state.selectedRoomId != null) {
          _scrollToRoomsSection();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Stack(
          children: [
            AppRefreshIndicator(
              onRefresh: () async {
                await context
                    .read<LoungeDetailsCubit>()
                    .getLoungeDetails(widget.lounge.id);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
                    buildWhen: (previous, current) => previous.lounge != current.lounge,
                    builder: (context, state) {
                      return LoungeDetailsAppBar(
                          lounge: _displayLounge(state), heroTag: widget.heroTag);
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
            LoungeDetailsBottomBar(lounge: widget.lounge),
          ],
        ),
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
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_rounded, color: Colors.black, size: 20.sp),
            10.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: widget.lounge.getDiscountTitle(isArabic) ??
                        AppStrings.discount.tr(),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  if (widget.lounge.discountPercentage > 0)
                    AppText(
                      text:
                          "${widget.lounge.discountPercentage}% ${AppStrings.discount.tr()}",
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                ],
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
    if (tournaments.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final tournament = tournaments.first;
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.neonBlue.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 24.sp),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: tournament.title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  AppText(
                    text: "${tournament.game} • ${tournament.entryFee} ${AppStrings.egp.tr()}",
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                context.pushNamed(
                  RouterKeys.tournamentDetails,
                  pathParameters: {'id': tournament.id},
                );
              },
              child: AppText(
                text: AppStrings.cardDetails.tr(),
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
