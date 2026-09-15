import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
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
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            if (state.participations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.trophy_off,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.noResults.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.participations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
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
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Orbitron',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.neonBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                participant.paymentStatus.toDbString(),
                                style: const TextStyle(
                                  color: AppColors.neonBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(TablerIcons.device_gamepad, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              gameName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(width: 16),
                            const Icon(TablerIcons.building, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              loungeName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${AppStrings.bookingDate.tr()}: $formattedDate',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              participant.status.toDbString(),
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
}
