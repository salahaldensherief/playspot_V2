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
import '../../../../art_core/widgets/bottom_sheets/manual_payment_bottom_sheet.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/buttons/directions_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../domain/entities/tournament_entity.dart';
import '../bracket/tournament_bracket_view.dart';
import '../widgets/tournament_status_badge.dart';
import 'tournament_details_cubit.dart';
import 'tournament_details_state.dart';
import 'widgets/tournament_overview_card.dart';
import 'widgets/tournament_participants_card.dart';
import 'widgets/tournament_prizes_tab.dart';
import 'widgets/tournament_rules_card.dart';

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
        final errorMsg = state.errorMessage;
        if (errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText(text: errorMsg, color: Colors.white),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        final successMsg = state.successMessage;
        if (successMsg != null) {
          if (successMsg == 'registeredSuccessfully' && state.tournament != null) {
            _showRegistrationSuccessDialog(context, state.tournament!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: AppText(text: successMsg.tr(), color: Colors.white),
                backgroundColor: AppColors.success,
              ),
            );
          }
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
                  Icon(TablerIcons.alert_circle, size: 48.sp, color: AppColors.danger),
                  SizedBox(height: 12.h),
                  AppText(
                    text: state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
                    color: AppColors.textSecondary,
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
                expandedHeight: 220.h,
                pinned: true,
                backgroundColor: AppColors.scaffoldBackground,
                leading: const BackButtonWidget(),
                actions: [
                  if (state.userParticipant != null &&
                      state.userParticipant?.status != ParticipantStatus.withdrawn &&
                      state.userParticipant?.status != ParticipantStatus.cancelled &&
                      state.userParticipant?.status != ParticipantStatus.eliminated)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      child: GlassContainer(
                        borderRadius: 8.r,
                        blur: 8,
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        borderColor: AppColors.successBorder,
                        color: AppColors.success.withValues(alpha: 0.15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(TablerIcons.circle_check, color: AppColors.success, size: 14.sp),
                            SizedBox(width: 4.w),
                            AppText(
                              text: state.userParticipant?.checkedIn == true
                                  ? AppStrings.checkedIn.tr()
                                  : AppStrings.confirmed.tr(),
                              color: AppColors.success,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (tournament.imageUrl?.isNotEmpty == true)
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
                      PositionedDirectional(
                        bottom: 16.h,
                        start: 16.w,
                        end: 16.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TournamentStatusBadge(status: tournament.status),
                            SizedBox(height: 8.h),
                            AppText(
                              text: tournament.title,
                              color: AppColors.textPrimary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
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
                // Tab 1: Rules & Details
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TournamentOverviewCard(tournament: tournament),
                      SizedBox(height: 16.h),
                      TournamentParticipantsCard(tournament: tournament),
                      SizedBox(height: 16.h),
                      TournamentRulesCard(tournament: tournament),
                      if (_buildActionButtons(context, state) != null) ...[
                        SizedBox(height: 20.h),
                        _buildActionButtons(context, state)!,
                      ],
                    ],
                  ),
                ),

                // Tab 2: Prizes
                TournamentPrizesTab(prizes: state.prizes),

                // Tab 3: Bracket
                Padding(
                  padding: EdgeInsets.only(top: 16.h),
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
        );
      },
    );
  }

  Widget? _buildActionButtons(BuildContext context, TournamentDetailsState state) {
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
      if (tournament.status == TournamentStatus.registrationOpen && !isRegistrationClosed) {
        return GlassContainer(
          padding: EdgeInsets.all(16.w),
          borderRadius: 16.r,
          borderColor: AppColors.borderDefault,
          color: AppColors.cardBackground.withValues(alpha: 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassContainer(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                borderRadius: 8.r,
                borderColor: AppColors.danger.withValues(alpha: 0.3),
                color: AppColors.danger.withValues(alpha: 0.12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(TablerIcons.info_circle, color: AppColors.danger, size: 16.sp),
                    SizedBox(width: 8.w),
                    AppText(
                      text: participant.status == ParticipantStatus.withdrawn
                          ? AppStrings.withdrawSuccess.tr()
                          : participant.status.name.tr(),
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              AppButton(
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
            ],
          ),
        );
      } else {
        return GlassContainer(
          padding: EdgeInsets.all(16.w),
          borderRadius: 16.r,
          borderColor: AppColors.borderDefault,
          color: AppColors.cardBackground.withValues(alpha: 0.5),
          child: Center(
            child: AppText(
              text: participant.status == ParticipantStatus.withdrawn
                  ? AppStrings.withdrawSuccess.tr()
                  : participant.status.name.tr(),
              color: AppColors.danger,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        );
      }
    }

    if (state.canCheckIn) {
      return GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: 16.r,
        borderColor: AppColors.borderDefault,
        color: AppColors.cardBackground.withValues(alpha: 0.5),
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
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(child: _buildDirectionsButton(context, tournament)),
                SizedBox(width: 8.w),
                Expanded(child: _buildWithdrawButton(context, state)),
              ],
            ),
          ],
        ),
      );
    }

    if (participant != null && participant.checkedIn) {
      return GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: 16.r,
        borderColor: AppColors.borderDefault,
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(TablerIcons.circle_check, color: AppColors.success, size: 20.sp),
                SizedBox(width: 8.w),
                AppText(
                  text: AppStrings.checkedIn.tr(),
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(child: _buildDirectionsButton(context, tournament)),
                SizedBox(width: 8.w),
                Expanded(child: _buildWithdrawButton(context, state)),
              ],
            ),
          ],
        ),
      );
    }

    if (participant != null && participant.paymentStatus == PaymentStatus.rejected) {
      return GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: 16.r,
        borderColor: AppColors.borderDefault,
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              borderRadius: 12.r,
              borderColor: AppColors.danger,
              color: AppColors.danger.withValues(alpha: 0.15),
              child: Column(
                children: [
                  AppText(
                    text: AppStrings.paymentRejected.tr(),
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                  if (participant.paymentRejectionReason != null && participant.paymentRejectionReason!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    AppText(
                      text: AppStrings.paymentRejectedReason.tr(args: [participant.paymentRejectionReason!]),
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12.h),
            AppButton(
              buttonConfig: ButtonConfig.gradient(
                gradient: AppColors.primaryGradient,
                glowColor: AppColors.neonBlueAlt,
                width: double.infinity,
              ),
              content: ButtonContent(label: AppStrings.uploadReceipt.tr()),
              behavior: TapBehavior(
                isLoading: state.isSubmittingPayment,
                onTap: () => _openPaymentModal(context, tournament, isRetry: true),
              ),
            ),
          ],
        ),
      );
    }

    if (participant != null && participant.paymentStatus == PaymentStatus.pending) {
      return GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: 16.r,
        borderColor: AppColors.borderDefault,
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              borderRadius: 12.r,
              borderColor: AppColors.warning,
              color: AppColors.warning.withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(TablerIcons.clock, color: AppColors.warning, size: 18.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: AppText(
                      text: AppStrings.manualTransfer.tr(),
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(child: _buildDirectionsButton(context, tournament)),
                SizedBox(width: 8.w),
                Expanded(child: _buildWithdrawButton(context, state)),
              ],
            ),
          ],
        ),
      );
    }

    if (participant == null && tournament.status == TournamentStatus.registrationOpen && !isRegistrationClosed) {
      return GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: 16.r,
        borderColor: AppColors.borderDefault,
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        child: AppButton(
          buttonConfig: ButtonConfig.gradient(
            gradient: AppColors.primaryGradient,
            glowColor: AppColors.neonBlueAlt,
            width: double.infinity,
          ),
          content: ButtonContent(label: AppStrings.registerForTournament.tr()),
          behavior: TapBehavior(
            isLoading: state.isRegistering,
            onTap: () {
              if (tournament.entryFee > 0) {
                _openPaymentModal(context, tournament);
              } else {
                context.read<TournamentDetailsCubit>().registerForTournament();
              }
            },
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildDirectionsButton(BuildContext context, TournamentEntity tournament) {
    return DirectionsButton(
      loungeName: tournament.loungeName,
      loungeLocation: tournament.cityName,
      mapsLink: null,
      height: 45.h,
      isPrimary: false,
    );
  }

  Widget _buildWithdrawButton(BuildContext context, TournamentDetailsState state) {
    return AppButton(
      buttonConfig: ButtonConfig(
        backgroundColor: Colors.transparent,
        borderColor: AppColors.danger.withValues(alpha: 0.5),
        isOutlined: true,
        height: 45.h,
      ),
      content: ButtonContent(
        label: AppStrings.withdrawFromTournament.tr(),
      ),
      behavior: TapBehavior(
        isLoading: state.isWithdrawing,
        onTap: () => _confirmWithdrawal(context),
      ),
    );
  }

  void _openPaymentModal(BuildContext context, TournamentEntity tournament, {bool isRetry = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ManualPaymentBottomSheet(
        amount: tournament.entryFee,
        loungeName: tournament.loungeName ?? 'PlaySpot',
        onConfirm: (method, receiptFile, senderPhone) {
          context.read<TournamentDetailsCubit>().submitPayment(
            paymentMethod: method,
            receiptFile: receiptFile,
          );
        },
      ),
    );
  }

  void _confirmWithdrawal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: AppText(text: AppStrings.withdrawFromTournament.tr(), color: Colors.white),
        content: AppText(text: AppStrings.withdrawConfirmation.tr(), color: AppColors.textSecondary),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                buttonConfig: ButtonConfig(
                  backgroundColor: Colors.transparent,
                  height: 38.h,
                  width: 80.w,
                ),
                content: ButtonContent(
                  label: AppStrings.cancel.tr(),
                ),
                behavior: TapBehavior(
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ),
              SizedBox(width: 8.w),
              AppButton(
                buttonConfig: ButtonConfig(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                  borderColor: AppColors.danger.withValues(alpha: 0.4),
                  height: 38.h,
                  width: 130.w,
                ),
                content: ButtonContent(
                  label: AppStrings.withdrawFromTournament.tr(),
                ),
                behavior: TapBehavior(
                  onTap: () {
                    Navigator.pop(dialogContext);
                    context.read<TournamentDetailsCubit>().withdrawFromTournament();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRegistrationSuccessDialog(BuildContext context, TournamentEntity tournament) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              padding: EdgeInsets.all(16.w),
              borderRadius: 50.r,
              blur: 8,
              borderColor: AppColors.successBorder,
              color: AppColors.success.withValues(alpha: 0.15),
              child: Icon(TablerIcons.circle_check, color: AppColors.success, size: 48.sp),
            ),
            SizedBox(height: 16.h),
            AppText(
              text: AppStrings.registeredSuccessfully.tr(),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            AppButton(
              buttonConfig: ButtonConfig.gradient(
                gradient: AppColors.primaryGradient,
                glowColor: AppColors.neonBlueAlt,
                width: double.infinity,
              ),
              content: ButtonContent(label: AppStrings.close.tr()),
              behavior: TapBehavior(
                onTap: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
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
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
