import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/widgets/layout/app_refresh_indicator.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/text_field/app_text_field.dart';
import '../widgets/tournament_card.dart';
import 'tournaments_feed_cubit.dart';
import 'tournaments_feed_state.dart';

class TournamentsFeedScreen extends StatefulWidget {
  const TournamentsFeedScreen({super.key});

  @override
  State<TournamentsFeedScreen> createState() => _TournamentsFeedScreenState();
}

class _TournamentsFeedScreenState extends State<TournamentsFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statusFilters = [
    'All',
    'registration_open',
    'check_in_open',
    'in_progress',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    context.read<TournamentsFeedCubit>().loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: const BackButtonWidget(),
        title: AppText(
          text: AppStrings.tournaments.tr(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.neonBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                TablerIcons.history,
                color: AppColors.neonBlue,
                size: 18.sp,
              ),
            ),
            tooltip: AppStrings.myTournamentHistory.tr(),
            onPressed: () {
              context.pushNamed(RouterKeys.tournamentHistory);
            },
          ),
          SizedBox(width: 8.w),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Location Prompt Banner
            BlocSelector<TournamentsFeedCubit, TournamentsFeedState, bool>(
              selector: (state) => state.isLocationDisabled,
              builder: (context, isLocationDisabled) {
                if (!isLocationDisabled) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        TablerIcons.location_off,
                        color: AppColors.neonPurple,
                        size: 20.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: AppText(
                          text: AppStrings.enableLocationForNearbyTournaments
                              .tr(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Search Input with ValueListenableBuilder for clear icon
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return AppTextField(
                    controller: _searchController,
                    hint: AppStrings.searchTournamentsHint.tr(),
                    prefixIcon: TablerIcons.search,
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textSecondary,
                              size: 18.sp,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<TournamentsFeedCubit>()
                                  .onSearchChanged('');
                            },
                          )
                        : null,
                    onChanged: context
                        .read<TournamentsFeedCubit>()
                        .onSearchChanged,
                  );
                },
              ),
            ),

            BlocBuilder<TournamentsFeedCubit, TournamentsFeedState>(
              buildWhen: (before, after) =>
                  before.availableGames != after.availableGames ||
                  before.selectedGame != after.selectedGame,
              builder: (context, state) {
                if (state.availableGames.isEmpty) {
                  return const SizedBox.shrink();
                }
                final List<String?> games = [null, ...state.availableGames];
                return SizedBox(
                  height: 50.h,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    scrollDirection: Axis.horizontal,
                    itemCount: games.length,
                    separatorBuilder: (context, index) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      final game = games[index];
                      final selectedGame = state.selectedGame;
                      final isSelected = selectedGame == game;
                      return InkWell(
                        borderRadius: BorderRadius.circular(24.r),
                        onTap: () {
                          context.read<TournamentsFeedCubit>().filterByGame(
                            game,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonBlue.withValues(alpha: .14)
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonBlue
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Center(
                            child: AppText(
                              text: game ?? AppStrings.all.tr(),
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.neonBlue
                                    : AppColors.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 8.h),

            // Status Filter Chips
            SizedBox(
              height: 50.h,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (context, index) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final statusKey = _statusFilters[index];
                  return BlocSelector<
                    TournamentsFeedCubit,
                    TournamentsFeedState,
                    String?
                  >(
                    selector: (state) => state.selectedStatus,
                    builder: (context, selectedStatus) {
                      final isSelected =
                          (selectedStatus == null && statusKey == 'All') ||
                          selectedStatus == statusKey;

                      return InkWell(
                        borderRadius: BorderRadius.circular(24.r),
                        onTap: () {
                          context.read<TournamentsFeedCubit>().filterByStatus(
                            statusKey == 'All' ? null : statusKey,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonBlue
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonBlue
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Center(
                            child: AppText(
                              text: _getLocalizedStatus(statusKey),
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.black
                                    : AppColors.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            BlocBuilder<TournamentsFeedCubit, TournamentsFeedState>(
              buildWhen: (before, after) =>
                  before.tournaments != after.tournaments ||
                  before.selectedGame != after.selectedGame ||
                  before.selectedStatus != after.selectedStatus ||
                  before.searchQuery != after.searchQuery,
              builder: (context, state) =>
                  state.tournaments.isEmpty &&
                      state.selectedGame == null &&
                      state.selectedStatus == null &&
                      state.searchQuery.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        16.w,
                        2.h,
                        16.w,
                        4.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              text: AppStrings.tournamentResultsCount.tr(
                                namedArgs: {
                                  'count': '${state.tournaments.length}',
                                },
                              ),
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (state.selectedGame != null ||
                              state.selectedStatus != null ||
                              state.searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<TournamentsFeedCubit>()
                                    .clearFilters();
                              },
                              child: AppText(
                                text: AppStrings.clearTournamentFilters.tr(),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),

            // Tournaments List / Shimmer / Empty / Error
            Expanded(
              child: BlocBuilder<TournamentsFeedCubit, TournamentsFeedState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.tournaments != current.tournaments ||
                    previous.errorMessage != current.errorMessage,
                builder: (context, state) {
                  if (state.status == TournamentsFeedStatus.loading &&
                      state.tournaments.isEmpty) {
                    return const AppLoader(size: 40);
                  }

                  if (state.status == TournamentsFeedStatus.failure &&
                      state.tournaments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              TablerIcons.alert_circle,
                              size: 48.sp,
                              color: AppColors.danger,
                            ),
                            SizedBox(height: 12.h),
                            AppText(
                              text:
                                  state.errorMessage ??
                                  AppStrings.somethingWentWrong.tr(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16.h),
                            AppButton(
                              buttonConfig: ButtonConfig(
                                backgroundColor: Colors.transparent,
                                borderColor: AppColors.neonBlue,
                                isOutlined: true,
                              ),
                              content: ButtonContent(
                                label: AppStrings.retry.tr(),
                              ),
                              behavior: TapBehavior(
                                onTap: () {
                                  context
                                      .read<TournamentsFeedCubit>()
                                      .loadTournaments(isRefresh: true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.tournaments.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => AppRefreshIndicator(
                        onRefresh: () => context
                            .read<TournamentsFeedCubit>()
                            .loadTournaments(isRefresh: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      TablerIcons.trophy_off,
                                      size: 48.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 12.h),
                                    AppText(
                                      text: AppStrings.noTournamentsFound.tr(),
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AppRefreshIndicator(
                    onRefresh: () async {
                      await context
                          .read<TournamentsFeedCubit>()
                          .loadTournaments(isRefresh: true);
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      itemCount: state.tournaments.length,
                      itemBuilder: (context, index) {
                        final tournament = state.tournaments[index];
                        return TournamentCard(
                          tournament: tournament,
                          onTap: () {
                            context.pushNamed(
                              RouterKeys.tournamentDetails,
                              pathParameters: {'id': tournament.id},
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLocalizedStatus(String key) {
    switch (key) {
      case 'All':
        return AppStrings.all.tr();
      case 'registration_open':
        return AppStrings.registrationOpen.tr();
      case 'check_in_open':
        return AppStrings.checkInOpen.tr();
      case 'in_progress':
        return AppStrings.tournamentInProgress.tr();
      case 'completed':
        return AppStrings.tournamentCompleted.tr();
      default:
        return key;
    }
  }
}
