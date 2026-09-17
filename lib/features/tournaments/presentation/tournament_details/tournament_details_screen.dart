import 'package:cached_network_image/cached_network_image.dart';
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
import '../../domain/entities/tournament_entity.dart';
import '../bracket/tournament_bracket_view.dart';
import '../widgets/tournament_payment_bottom_sheet.dart';
import '../widgets/tournament_status_badge.dart';
import 'tournament_details_cubit.dart';
import 'tournament_details_state.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<TournamentDetailsCubit>().init(widget.tournamentId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TournamentDetailsCubit, TournamentDetailsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!.tr()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == TournamentDetailsStatus.loading && state.tournament == null) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: AppLoader(size: 40),
          );
        }

        if (state.status == TournamentDetailsStatus.failure && state.tournament == null) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              backgroundColor: AppColors.scaffoldBackground,
              leading: const BackButtonWidget(),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(TablerIcons.alert_circle, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage ?? 'somethingWentWrong'.tr(),
                    style: const TextStyle(color: AppColors.textSecondary),
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
                      onTap: () => context.read<TournamentDetailsCubit>().init(widget.tournamentId),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tournament = state.tournament!;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // Hero Header with Cover Image
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.scaffoldBackground,
                leading: const BackButtonWidget(),
                actions: [
                  if (state.userParticipant != null &&
                      state.userParticipant!.status != ParticipantStatus.withdrawn &&
                      state.userParticipant!.status != ParticipantStatus.cancelled &&
                      state.userParticipant!.status != ParticipantStatus.eliminated)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _showWithdrawConfirmationDialog(context),
                        icon: const Icon(TablerIcons.logout, color: AppColors.danger, size: 14),
                        label: Text(
                          AppStrings.withdrawFromTournament.tr(),
                          style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: tournament.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 800,
                          memCacheHeight: 500,
                          placeholder: (context, url) => Container(color: AppColors.mutedBackground),
                          errorWidget: (context, url, error) => Container(color: AppColors.mutedBackground),
                        )
                      else
                        Container(color: AppColors.mutedBackground),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              AppColors.scaffoldBackground,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TournamentStatusBadge(status: tournament.status),
                            const SizedBox(height: 8),
                            Text(
                              tournament.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Tab Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.neonBlue,
                    indicatorWeight: 3,
                    labelColor: AppColors.neonBlue,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: AppStrings.tournamentRules.tr()),
                      Tab(text: AppStrings.tournamentPrizes.tr()),
                      Tab(text: AppStrings.tournamentBracket.tr()),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Rules
                _buildRulesTab(tournament),

                // Tab 2: Prizes
                _buildPrizesTab(state.prizes),

                // Tab 3: Bracket
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TournamentBracketView(
                    matches: state.matches,
                    onMatchTap: (match) {
                      context.pushNamed(
                        RouterKeys.tournamentMatch,
                        pathParameters: {
                          'id': tournament.id,
                          'matchId': match.id,
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: (state.userParticipant != null &&
                  (state.userParticipant!.status == ParticipantStatus.confirmed ||
                   state.userParticipant!.status == ParticipantStatus.waitlist ||
                   state.userParticipant!.checkedIn ||
                   state.userParticipant!.status == ParticipantStatus.pendingPayment))
              ? null
              : _buildActionBottomBar(context, state),
        );
      },
    );
  }

  Widget _buildRulesTab(TournamentEntity tournament) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCard(tournament),
          const SizedBox(height: 16),
          _buildParticipantsCard(tournament),
          const SizedBox(height: 16),
          _buildRulesSectionCard(tournament),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(TournamentEntity tournament) {
    final scopeText = tournament.visibilityScope == TournamentVisibilityScope.city
        ? AppStrings.visibilityScopeCity.tr()
        : tournament.visibilityScope == TournamentVisibilityScope.radius
            ? AppStrings.visibilityScopeRadius.tr()
            : AppStrings.visibilityScopeAll.tr();

    final entryFeeText = tournament.entryFee > 0
        ? '${tournament.entryFee.toStringAsFixed(0)} ${AppStrings.egp.tr()}'
        : AppStrings.freeEntry.tr();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(TablerIcons.info_circle, color: AppColors.neonPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'tournamentDetails'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            icon: TablerIcons.device_gamepad,
            label: AppStrings.filterByGame.tr(),
            value: tournament.game,
          ),
          if (tournament.loungeName != null) ...[
            const SizedBox(height: 10),
            _buildInfoTile(
              icon: TablerIcons.building,
              label: AppStrings.loungeVenue.tr(),
              value: tournament.loungeName!,
            ),
          ],
          if (tournament.cityName != null) ...[
            const SizedBox(height: 10),
            _buildInfoTile(
              icon: TablerIcons.map_pin,
              label: AppStrings.city.tr(),
              value: tournament.cityName!,
            ),
          ],
          if (tournament.startDate != null) ...[
            const SizedBox(height: 10),
            _buildInfoTile(
              icon: TablerIcons.calendar_event,
              label: AppStrings.tournamentDate.tr(),
              value: DateFormat('yyyy-MM-dd HH:mm').format(tournament.startDate!),
            ),
          ],
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: TablerIcons.ticket,
            label: AppStrings.entryFee.tr(),
            value: entryFeeText,
            iconColor: tournament.entryFee > 0 ? AppColors.warning : AppColors.success,
            customValueWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (tournament.entryFee > 0 ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (tournament.entryFee > 0 ? AppColors.warning : AppColors.success).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                entryFeeText,
                style: TextStyle(
                  color: tournament.entryFee > 0 ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: TablerIcons.eye,
            label: AppStrings.visibilityScope.tr(),
            value: scopeText,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard(TournamentEntity tournament) {
    final remainingSeats = (tournament.maxParticipants - tournament.registeredParticipantsCount).clamp(0, tournament.maxParticipants);
    final double fillPercentage = tournament.bracketSize > 0
        ? (tournament.registeredParticipantsCount / tournament.bracketSize).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(TablerIcons.users, color: AppColors.neonBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.maxParticipants.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remainingSeats > 0
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: remainingSeats > 0 ? AppColors.successBorder : AppColors.dangerBorder,
                  ),
                ),
                child: Text(
                  '$remainingSeats ${AppStrings.remainingSeats.tr()}',
                  style: TextStyle(
                    color: remainingSeats > 0 ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.maxParticipants.tr(),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                '${tournament.registeredParticipantsCount} / ${tournament.bracketSize}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fillPercentage,
              minHeight: 8,
              backgroundColor: AppColors.mutedBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
            ),
          ),
          if (tournament.registrationClosesAt != null || tournament.checkInOpensAt != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
          ],
          if (tournament.registrationClosesAt != null) ...[
            _buildInfoTile(
              icon: TablerIcons.clock,
              label: AppStrings.registrationClosesAt.tr(),
              value: DateFormat('yyyy-MM-dd HH:mm').format(tournament.registrationClosesAt!),
            ),
            const SizedBox(height: 10),
          ],
          if (tournament.checkInOpensAt != null) ...[
            _buildInfoTile(
              icon: TablerIcons.clock_play,
              label: AppStrings.checkInWindow.tr(),
              value: '${DateFormat('HH:mm').format(tournament.checkInOpensAt!)} - ${tournament.checkInClosesAt != null ? DateFormat('HH:mm').format(tournament.checkInClosesAt!) : ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRulesSectionCard(TournamentEntity tournament) {
    final rulesText = tournament.rules != null && tournament.rules!.isNotEmpty
        ? tournament.rules!
        : (tournament.description ?? AppStrings.noRulesProvided.tr());

    final lines = rulesText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(TablerIcons.gavel, color: AppColors.neonBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.tournamentRules.tr(),
                style: const TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lines.length > 1)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lines.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final lineText = lines[index].replaceFirst(RegExp(r'^\d+[\.\-\)]\s*'), '');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonBlue.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.neonBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          lineText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mutedBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.neonBlue, width: 3),
                ),
              ),
              child: Text(
                rulesText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Widget? customValueWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mutedBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.neonBlue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.neonBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                customValueWidget ??
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizesTab(List<TournamentPrizeEntity> prizes) {
    if (prizes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.trophy_off, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'noResults'.tr(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrizePoolHeader(prizes),
          const SizedBox(height: 20),
          Text(
            AppStrings.tournamentPrizes.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prizes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildPrizeCard(prizes[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrizePoolHeader(List<TournamentPrizeEntity> prizes) {
    final totalAmount = prizes.fold(0.0, (sum, p) => sum + p.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppColors.tournamentPromoGradient,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withValues(alpha: 0.2),
              border: Border.all(color: AppColors.warning, width: 1.5),
            ),
            child: const Icon(
              TablerIcons.trophy,
              color: AppColors.warning,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tournamentPrizes.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalAmount.toStringAsFixed(0)} ${'egp'.tr()}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeCard(TournamentPrizeEntity prize) {
    final bool isFirst = prize.placement == 1;
    final bool isSecond = prize.placement == 2;
    final bool isThird = prize.placement == 3;

    final Color cardAccentColor = isFirst
        ? AppColors.warning
        : isSecond
            ? const Color(0xFFCBD5E1)
            : isThird
                ? const Color(0xFFCD7F32)
                : AppColors.neonBlue;

    final IconData rankIcon = isFirst
        ? TablerIcons.crown
        : isSecond
            ? TablerIcons.medal
            : isThird
                ? TablerIcons.award
                : TablerIcons.trophy;

    final String rankLabel = isFirst
        ? '1st'
        : isSecond
            ? '2nd'
            : isThird
                ? '3rd'
                : '#${prize.placement}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardAccentColor.withValues(alpha: isFirst ? 0.8 : 0.4),
          width: isFirst ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isFirst)
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cardAccentColor.withValues(alpha: 0.15),
              border: Border.all(color: cardAccentColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Center(
              child: Icon(
                rankIcon,
                color: cardAccentColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cardAccentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rankLabel,
                        style: TextStyle(
                          color: cardAccentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prize.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (prize.description != null && prize.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    prize.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardAccentColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${prize.amount.toStringAsFixed(0)} ${'egp'.tr()}',
              style: TextStyle(
                color: cardAccentColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildActionBottomBar(BuildContext context, TournamentDetailsState state) {
    final tournament = state.tournament;
    final participant = state.userParticipant;

    if (tournament == null) return null;

    final isRegistrationClosed = (tournament.registrationClosesAt != null &&
            DateTime.now().isAfter(tournament.registrationClosesAt!)) ||
        tournament.status == TournamentStatus.registrationClosed ||
        tournament.status == TournamentStatus.completed ||
        tournament.status == TournamentStatus.cancelled;

    if (participant != null &&
        (participant.status == ParticipantStatus.expired ||
            participant.status == ParticipantStatus.withdrawn ||
            participant.status == ParticipantStatus.cancelled ||
            participant.status == ParticipantStatus.eliminated ||
            participant.status == ParticipantStatus.noShow)) {
      return null;
    }

    // Case 1: Check-in available
    if (state.canCheckIn) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                buttonConfig: ButtonConfig.gradient(
                  gradient: AppColors.primaryGradient,
                  glowColor: AppColors.neonBlueAlt,
                  width: double.infinity,
                ),
                content: ButtonContent(label: AppStrings.checkIn.tr()),
                behavior: TapBehavior(
                  isLoading: state.isCheckingIn,
                  onTap: () => context.read<TournamentDetailsCubit>().checkIn(),
                ),
              ),
              const SizedBox(height: 8),
              _buildWithdrawButton(context, state),
            ],
          ),
        ),
      );
    }

    // Case 2: Checked In
    if (participant != null && participant.checkedIn) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.cardBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(TablerIcons.circle_check, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.checkedIn.tr(),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildWithdrawButton(context, state),
            ],
          ),
        ),
      );
    }

    // Case 3: Payment Rejected (MOB-05)
    if (participant != null && participant.paymentStatus == PaymentStatus.rejected) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Column(
                  children: [
                    Text(
                      AppStrings.paymentRejected.tr(),
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (participant.paymentRejectionReason != null && participant.paymentRejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.paymentRejectedReason.tr(args: [participant.paymentRejectionReason!]),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                buttonConfig: ButtonConfig.gradient(
                  gradient: AppColors.primaryGradient,
                  glowColor: AppColors.neonBlueAlt,
                  width: double.infinity,
                ),
                content: ButtonContent(label: AppStrings.uploadReceipt.tr()),
                behavior: TapBehavior(
                  isLoading: state.isSubmittingPayment,
                  onTap: () => _showPaymentBottomSheet(context, tournament),
                ),
              ),
              const SizedBox(height: 8),
              _buildWithdrawButton(context, state),
            ],
          ),
        ),
      );
    }

    // Case 4: Pending Payment -> Show Upload Receipt
    if (participant != null && participant.status == ParticipantStatus.pendingPayment) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                buttonConfig: ButtonConfig.gradient(
                  gradient: AppColors.primaryGradient,
                  glowColor: AppColors.neonBlueAlt,
                  width: double.infinity,
                ),
                content: ButtonContent(label: AppStrings.uploadReceipt.tr()),
                behavior: TapBehavior(
                  isLoading: state.isSubmittingPayment,
                  onTap: () => _showPaymentBottomSheet(context, tournament),
                ),
              ),
              const SizedBox(height: 8),
              _buildWithdrawButton(context, state),
            ],
          ),
        ),
      );
    }

    // Case 5: Confirmed or Waitlist -> Show status + Withdraw button
    if (participant != null && (participant.status == ParticipantStatus.confirmed || participant.status == ParticipantStatus.waitlist)) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.cardBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                participant.status == ParticipantStatus.waitlist ? AppStrings.waitlist.tr() : AppStrings.confirmed.tr(),
                style: const TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              _buildWithdrawButton(context, state),
            ],
          ),
        ),
      );
    }

    // Case 6: Registration Open & Not yet registered
    if (participant == null && tournament.status == TournamentStatus.registrationOpen && !isRegistrationClosed) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            buttonConfig: ButtonConfig.gradient(
              gradient: AppColors.primaryGradient,
              glowColor: AppColors.neonBlueAlt,
              width: double.infinity,
            ),
            content: ButtonContent(label: AppStrings.registerForTournament.tr()),
            behavior: TapBehavior(
              isLoading: state.isRegistering,
              onTap: () => context.read<TournamentDetailsCubit>().registerForTournament(),
            ),
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildWithdrawButton(BuildContext context, TournamentDetailsState state) {
    return AppButton(
      content: ButtonContent(
        label: AppStrings.withdrawFromTournament.tr(),
        icon: const Icon(TablerIcons.user_minus, size: 18, color: AppColors.danger),
      ),
      behavior: ButtonBehavior.tap(
        isEnabled: !state.isWithdrawing,
        onTap: () => _showWithdrawConfirmationDialog(context),
      ),
      buttonConfig: ButtonConfig(
        height: 40.h,
        backgroundColor: Colors.transparent,
        borderColor: AppColors.danger,
        isOutlined: true,
        textStyle: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _showPaymentBottomSheet(BuildContext context, TournamentEntity tournament) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => TournamentPaymentBottomSheet(
        entryFee: tournament.entryFee,
        onSubmit: (method, file) async {
          await context.read<TournamentDetailsCubit>().submitPayment(
                paymentMethod: method,
                receiptFile: file,
              );
        },
      ),
    );
  }

  void _showWithdrawConfirmationDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.danger),
        ),
        title: Text(
          AppStrings.withdrawFromTournament.tr(),
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        content: Text(
          AppStrings.withdrawConfirmation.tr(),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  content: ButtonContent(label: AppStrings.cancel.tr()),
                  behavior: ButtonBehavior.tap(
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                  buttonConfig: ButtonConfig(
                    height: 40.h,
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.textSecondary,
                    isOutlined: true,
                    borderRadius: 12.r,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  content: ButtonContent(label: AppStrings.withdrawFromTournament.tr()),
                  behavior: ButtonBehavior.tap(
                    onTap: () {
                      Navigator.pop(dialogContext);
                      parentContext.read<TournamentDetailsCubit>().withdrawFromTournament();
                    },
                  ),
                  buttonConfig: ButtonConfig(
                    height: 40.h,
                    backgroundColor: AppColors.danger,
                    borderRadius: 12.r,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.scaffoldBackground,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
