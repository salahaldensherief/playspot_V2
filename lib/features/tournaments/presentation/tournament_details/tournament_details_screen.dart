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
                              Colors.black.withOpacity(0.4),
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
                TournamentBracketView(
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
              ],
            ),
          ),
          bottomNavigationBar: _buildActionBottomBar(context, state),
        );
      },
    );
  }

  Widget _buildRulesTab(TournamentEntity tournament) {
    final remainingSeats = (tournament.maxParticipants - tournament.registeredParticipantsCount).clamp(0, tournament.maxParticipants);
    final scopeText = tournament.visibilityScope == TournamentVisibilityScope.city
        ? AppStrings.visibilityScopeCity.tr()
        : tournament.visibilityScope == TournamentVisibilityScope.radius
            ? AppStrings.visibilityScopeRadius.tr()
            : AppStrings.visibilityScopeAll.tr();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Metadata Section
          _buildInfoRow(TablerIcons.device_gamepad, AppStrings.filterByGame.tr(), tournament.game),
          if (tournament.loungeName != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(TablerIcons.building, AppStrings.loungeVenue.tr(), tournament.loungeName!),
          ],
          if (tournament.cityName != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(TablerIcons.map_pin, AppStrings.city.tr(), tournament.cityName!),
          ],
          if (tournament.startDate != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              TablerIcons.calendar_event,
              AppStrings.tournamentDate.tr(),
              DateFormat('yyyy-MM-dd HH:mm').format(tournament.startDate!),
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            TablerIcons.cash,
            AppStrings.entryFee.tr(),
            tournament.entryFee > 0 ? '${tournament.entryFee.toStringAsFixed(0)} ${AppStrings.egp.tr()}' : AppStrings.freeEntry.tr(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            TablerIcons.users,
            AppStrings.maxParticipants.tr(),
            '${tournament.registeredParticipantsCount} / ${tournament.bracketSize}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            TablerIcons.user_check,
            AppStrings.remainingSeats.tr(),
            '$remainingSeats',
          ),
          if (tournament.registrationClosesAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              TablerIcons.clock,
              AppStrings.registrationClosesAt.tr(),
              DateFormat('yyyy-MM-dd HH:mm').format(tournament.registrationClosesAt!),
            ),
          ],
          if (tournament.checkInOpensAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              TablerIcons.clock_play,
              AppStrings.checkInWindow.tr(),
              '${DateFormat('HH:mm').format(tournament.checkInOpensAt!)} - ${tournament.checkInClosesAt != null ? DateFormat('HH:mm').format(tournament.checkInClosesAt!) : ''}',
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(TablerIcons.eye, AppStrings.visibilityScope.tr(), scopeText),

          const Divider(color: AppColors.divider, height: 32),
          Text(
            AppStrings.tournamentRules.tr(),
            style: const TextStyle(
              color: AppColors.neonBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tournament.rules != null && tournament.rules!.isNotEmpty
                ? tournament.rules!
                : (tournament.description ?? AppStrings.noRulesProvided.tr()),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPrizesTab(List<TournamentPrizeEntity> prizes) {
    if (prizes.isEmpty) {
      return Center(
        child: Text(
          'noResults'.tr(),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: prizes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final prize = prizes[index];
        final bool isFirst = prize.placement == 1;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFirst ? AppColors.warning : AppColors.neonBlue.withOpacity(0.3),
              width: isFirst ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isFirst)
                BoxShadow(
                  color: AppColors.warning.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isFirst ? AppColors.warning.withOpacity(0.2) : AppColors.mutedBackground,
                radius: 20,
                child: Icon(
                  TablerIcons.trophy,
                  color: isFirst ? AppColors.warning : AppColors.neonBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prize.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (prize.description != null)
                      Text(
                        prize.description!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${prize.amount.toStringAsFixed(0)} ${'egp'.tr()}',
                style: TextStyle(
                  color: isFirst ? AppColors.warning : AppColors.neonBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
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
                  color: AppColors.danger.withOpacity(0.15),
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
