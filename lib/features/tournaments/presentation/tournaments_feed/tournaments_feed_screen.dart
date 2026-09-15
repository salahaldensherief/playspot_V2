import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../../../art_core/widgets/shimmer/lounge_card_shimmer.dart';
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
            const Icon(TablerIcons.trophy, color: AppColors.neonBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              AppStrings.tournaments.tr().toUpperCase(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
              ),
              child: const Icon(TablerIcons.history, color: AppColors.neonBlue, size: 18),
            ),
            tooltip: AppStrings.myTournamentHistory.tr(),
            onPressed: () {
              context.pushNamed(RouterKeys.tournamentHistory);
            },
          ),
          const SizedBox(width: 8),
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(TablerIcons.location_off, color: AppColors.neonPurple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'enableLocationForNearbyTournaments'.tr(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppTextField(
                controller: _searchController,
                hint: 'searchLoungesHint'.tr(),
                prefixIcon: TablerIcons.search,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<TournamentsFeedCubit>().onSearchChanged('');
                        },
                      )
                    : null,
                onChanged: (val) {
                  context.read<TournamentsFeedCubit>().onSearchChanged(val);
                },
              ),
            ),

            // Game Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _gameFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonBlue : AppColors.tournamentFilterBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.neonBlue : AppColors.neonBlue.withValues(alpha: 0.2),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonBlue.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              game == 'All' ? 'all'.tr() : game,
                              style: TextStyle(
                                color: isSelected ? AppColors.black : AppColors.white,
                                fontSize: 12,
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
            const SizedBox(height: 8),

            // Status Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonPurple : AppColors.tournamentFilterBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.neonPurple : AppColors.neonPurple.withValues(alpha: 0.2),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonPurple.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              _getLocalizedStatus(statusKey),
                              style: TextStyle(
                                color: isSelected ? AppColors.white : AppColors.textSecondary,
                                fontSize: 12,
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
            const SizedBox(height: 12),

            // Tournaments List / Shimmer / Empty / Error
            Expanded(
              child: BlocBuilder<TournamentsFeedCubit, TournamentsFeedState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.tournaments != current.tournaments ||
                    previous.errorMessage != current.errorMessage,
                builder: (context, state) {
                  if (state.status == TournamentsFeedStatus.loading && state.tournaments.isEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (context, index) => const LoungeCardShimmer(),
                    );
                  }

                  if (state.status == TournamentsFeedStatus.failure && state.tournaments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              TablerIcons.alert_circle,
                              size: 48,
                              color: AppColors.danger,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage ?? 'somethingWentWrong'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            AppButton(
                              buttonConfig: ButtonConfig(
                                backgroundColor: Colors.transparent,
                                borderColor: AppColors.neonBlue,
                                isOutlined: true,
                              ),
                              content: ButtonContent(label: 'retry'.tr()),
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
                    return RefreshIndicator(
                      color: AppColors.neonBlue,
                      backgroundColor: AppColors.cardBackground,
                      onRefresh: () async {
                        await context.read<TournamentsFeedCubit>().loadTournaments(isRefresh: true);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(
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
                                  'noTournamentsFound'.tr(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
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

                  return RefreshIndicator(
                    color: AppColors.neonBlue,
                    backgroundColor: AppColors.cardBackground,
                    onRefresh: () async {
                      await context.read<TournamentsFeedCubit>().loadTournaments(isRefresh: true);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
