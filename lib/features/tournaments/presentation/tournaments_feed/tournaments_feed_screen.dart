import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
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
        title: Text(
          'tournaments'.tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
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
              height: 40,
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
                      return ChoiceChip(
                        label: Text(game == 'All' ? 'all'.tr() : game),
                        selected: isSelected,
                        onSelected: (selected) {
                          context.read<TournamentsFeedCubit>().filterByGame(game == 'All' ? null : game);
                        },
                        selectedColor: AppColors.neonBlue,
                        backgroundColor: AppColors.cardBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.black : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
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
              height: 40,
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

                      return ChoiceChip(
                        label: Text(_getLocalizedStatus(statusKey)),
                        selected: isSelected,
                        onSelected: (selected) {
                          context.read<TournamentsFeedCubit>().filterByStatus(statusKey == 'All' ? null : statusKey);
                        },
                        selectedColor: AppColors.neonPurple,
                        backgroundColor: AppColors.cardBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.neonPurple : AppColors.borderDefault,
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
                                  color: AppColors.textSecondary.withOpacity(0.5),
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
        return 'all'.tr();
      case 'registration_open':
        return 'registrationOpen'.tr();
      case 'check_in_open':
        return 'checkInOpen'.tr();
      case 'in_progress':
        return 'tournamentInProgress'.tr();
      case 'completed':
        return 'tournamentCompleted'.tr();
      default:
        return key;
    }
  }
}
