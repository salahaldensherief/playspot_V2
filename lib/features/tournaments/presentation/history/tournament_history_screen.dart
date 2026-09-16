import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
import 'tournament_history_cubit.dart';
import 'tournament_history_state.dart';

class TournamentHistoryScreen extends StatefulWidget {
  const TournamentHistoryScreen({super.key});

  @override
  State<TournamentHistoryScreen> createState() => _TournamentHistoryScreenState();
}

class _TournamentHistoryScreenState extends State<TournamentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TournamentHistoryCubit>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: const BackButtonWidget(),
        title: Text(
          AppStrings.myTournamentHistory.tr(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocBuilder<TournamentHistoryCubit, TournamentHistoryState>(
          builder: (context, state) {
            if (state.status == TournamentHistoryStatus.loading) {
              return const Center(child: AppLoader(size: 40));
            }

            if (state.status == TournamentHistoryStatus.failure) {
              return Center(
                child: Text(
                  state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
                ),
              );
            }

            if (state.participations.isEmpty) {
              return RefreshIndicator(
                color: AppColors.neonBlue,
                backgroundColor: AppColors.cardBackground,
                onRefresh: () async {
                  await context.read<TournamentHistoryCubit>().loadHistory();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 120.h),
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
                            AppStrings.noResults.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.neonBlue,
              backgroundColor: AppColors.cardBackground,
              onRefresh: () async {
                await context.read<TournamentHistoryCubit>().loadHistory();
              },
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: state.participations.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final item = state.participations[index];
                  final participant = item.participant;
                  final tournament = item.tournament;

                  final String tournamentTitle = tournament?.title ?? 'Tournament';
                  final String loungeName = tournament?.loungeName ?? '-';
                  final String gameName = tournament?.game ?? '-';
                  final DateTime? date = participant.createdAt ?? tournament?.startDate;
                  final String formattedDate = date != null ? DateFormat('yyyy-MM-dd').format(date) : '-';

                  return InkWell(
                    onTap: () {
                      if (tournament != null) {
                        context.pushNamed(
                          RouterKeys.tournamentDetails,
                          pathParameters: {'id': tournament.id},
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tournamentTitle,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    fontFamily: 'Orbitron',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: AppColors.neonBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  participant.paymentStatus.toLocalizedName(),
                                  style: TextStyle(
                                    color: AppColors.neonBlue,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(TablerIcons.device_gamepad, size: 14.sp, color: AppColors.textSecondary),
                              SizedBox(width: 4.w),
                              Text(
                                gameName,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
                              ),
                              SizedBox(width: 16.w),
                              Icon(TablerIcons.building, size: 14.sp, color: AppColors.textSecondary),
                              SizedBox(width: 4.w),
                              Text(
                                loungeName,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.bookingDate.tr()}: $formattedDate',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                              ),
                              Text(
                                participant.status.toLocalizedName(),
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
