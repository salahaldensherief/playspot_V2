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

  final List<String> _gameFilters = ['All', 'FIFA', 'EA FC 24', 'Tekken 8', 'Mortal Kombat', 'Rocket League'];
  final List<String> _statusFilters = [
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.trophy, color: AppColors.neonBlue, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              AppStrings.tournaments.tr().toUpperCase(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
              ),
              child: Icon(TablerIcons.history, color: AppColors.neonBlue, size: 18.sp),
            ),
            tooltip: AppStrings.myTournamentHistory.tr(),
            onPressed: () {
              context.pushNamed(RouterKeys.tournamentHistory);
            },
          ),
          SizedBox(width: 8.w),
        ],
        centerTitle: true,
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(TablerIcons.location_off, color: AppColors.neonPurple, size: 20.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          AppStrings.enableLocationForNearbyTournaments.tr(),
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
                    hint: AppStrings.searchLoungesHint.tr(),
                    prefixIcon: TablerIcons.search,
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18.sp),
                            onPressed: () {
                              _searchController.clear();
                              context.read<TournamentsFeedCubit>().onSearchChanged('');
                            },
                          )
                        : null,
                    onChanged: context.read<TournamentsFeedCubit>().onSearchChanged,
                  );
                },
              ),
            ),

            // Game Filter Chips
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemCount: _gameFilters.length,
                separatorBuilder: (context, index) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final game = _gameFilters[index];
                  return BlocSelector<TournamentsFeedCubit, TournamentsFeedState, String?>(
                    selector: (state) => state.selectedGame,
                    builder: (context, selectedGame) {
                      final isSelected = (selectedGame == null && game == 'All') || selectedGame == game;
                      return GestureDetector(
                        onTap: () {
                          context.read<TournamentsFeedCubit>().filterByGame(game == 'All' ? null : game);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonBlue : AppColors.tournamentFilterBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected ? AppColors.neonBlue : AppColors.neonBlue.withValues(alpha: 0.2),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonBlue.withValues(alpha: 0.4),
                                      blurRadius: 8.r,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              game == 'All' ? AppStrings.all.tr() : game,
                              style: TextStyle(
                                color: isSelected ? AppColors.black : AppColors.white,
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                fontFamily: isSelected ? 'Orbitron' : null,
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
            SizedBox(height: 8.h),

            // Status Filter Chips
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (context, index) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final statusKey = _statusFilters[index];
                  return BlocSelector<TournamentsFeedCubit, TournamentsFeedState, String?>(
                    selector: (state) => state.selectedStatus,
                    builder: (context, selectedStatus) {
                      final isSelected = (selectedStatus == null && statusKey == 'All') || selectedStatus == statusKey;

                      return GestureDetector(
                        onTap: () {
                          context.read<TournamentsFeedCubit>().filterByStatus(statusKey == 'All' ? null : statusKey);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonPurple : AppColors.tournamentFilterBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected ? AppColors.neonPurple : AppColors.neonPurple.withValues(alpha: 0.2),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonPurple.withValues(alpha: 0.4),
                                      blurRadius: 8.r,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              _getLocalizedStatus(statusKey),
                              style: TextStyle(
                                color: isSelected ? AppColors.white : AppColors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

            // Tournaments List / Shimmer / Empty / Error
            Expanded(
              child: BlocBuilder<TournamentsFeedCubit, TournamentsFeedState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.tournaments != current.tournaments ||
                    previous.errorMessage != current.errorMessage,
                builder: (context, state) {
                  if (state.status == TournamentsFeedStatus.loading && state.tournaments.isEmpty) {
                    return const AppLoader(size: 40);
                  }

                  if (state.status == TournamentsFeedStatus.failure && state.tournaments.isEmpty) {
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
                            Text(
                              state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
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
                              content: ButtonContent(label: AppStrings.retry.tr()),
                              behavior: TapBehavior(
                                onTap: () {
                                  context.read<TournamentsFeedCubit>().loadTournaments(isRefresh: true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.tournaments.isEmpty) {
                    return AppRefreshIndicator(
                      onRefresh: () async {
                        await context.read<TournamentsFeedCubit>().loadTournaments(isRefresh: true);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 80.h),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  TablerIcons.trophy_off,
                                  size: 64.sp,
                                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  AppStrings.noTournamentsFound.tr(),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return AppRefreshIndicator(
                    onRefresh: () async {
                      await context.read<TournamentsFeedCubit>().loadTournaments(isRefresh: true);
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
