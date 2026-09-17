import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/widgets/notifications/game_hud_toast.dart';
import '../../domain/entities/tournament_entity.dart';
import '../widgets/match_countdown_timer.dart';
import 'tournament_match_cubit.dart';
import 'tournament_match_state.dart';

class TournamentMatchScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;

  const TournamentMatchScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  State<TournamentMatchScreen> createState() => _TournamentMatchScreenState();
}

class _TournamentMatchScreenState extends State<TournamentMatchScreen> {
  final TextEditingController _disputeReasonController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<TournamentMatchCubit>().loadMatch(
          tournamentId: widget.tournamentId,
          matchId: widget.matchId,
        );
  }

  @override
  void dispose() {
    _disputeReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked != null && mounted) {
        context.read<TournamentMatchCubit>().setProofFile(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        GameHudToast.show(
          context,
          AppStrings.errorPickingImage.tr(args: ['$e']),
          type: ToastType.error,
        );
      }
    }
  }

  void _showDisputeDialog() {
    _disputeReasonController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.danger),
        ),
        title: Text(
          AppStrings.disputeResult.tr(),
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            fontFamily: 'Orbitron',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.disputeReason.tr(),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _disputeReasonController,
              maxLines: 3,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: AppStrings.enterDisputeReason.tr(),
                hintStyle: TextStyle(color: AppColors.hintText, fontSize: 12.sp),
                filled: true,
                fillColor: AppColors.mutedBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            buttonConfig: ButtonConfig(
              backgroundColor: Colors.transparent,
              borderColor: AppColors.borderDefault,
              isOutlined: true,
              width: 90.w,
            ),
            content: ButtonContent(label: AppStrings.close.tr()),
            behavior: TapBehavior(
              onTap: () => Navigator.pop(dialogContext),
            ),
          ),
          AppButton(
            buttonConfig: ButtonConfig(
              backgroundColor: AppColors.danger,
              width: 120.w,
            ),
            content: ButtonContent(label: AppStrings.disputeResult.tr()),
            behavior: TapBehavior(
              onTap: () {
                final reason = _disputeReasonController.text.trim();
                if (reason.isEmpty) {
                  GameHudToast.show(
                    context,
                    AppStrings.enterDisputeReason.tr(),
                    type: ToastType.error,
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                context.read<TournamentMatchCubit>().disputeResult(reason);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TournamentMatchCubit, TournamentMatchState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          GameHudToast.show(
            context,
            state.errorMessage!,
            type: ToastType.error,
          );
        }
        if (state.successMessage != null) {
          GameHudToast.show(
            context,
            state.successMessage!.tr(),
            type: ToastType.success,
          );
        }
      },
      builder: (context, state) {
        if (state.status == MatchScreenStatus.loading && state.match == null) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: AppLoader(size: 40),
          );
        }

        if (state.match == null) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(leading: const BackButtonWidget()),
            body: Center(
              child: Text(
                AppStrings.noResults.tr(),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
              ),
            ),
          );
        }

        final match = state.match!;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: AppColors.scaffoldBackground,
            elevation: 0,
            leading: const BackButtonWidget(),
            title: Text(
              AppStrings.matchDetails.tr(),
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
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Countdown Timer Header (If pending_confirmation)
                  if (match.status == MatchStatus.pendingConfirmation && match.confirmationDeadline != null) ...[
                    MatchCountdownTimer(
                      deadline: match.confirmationDeadline!,
                      onExpired: () {
                        context.read<TournamentMatchCubit>().confirmResult();
                      },
                    ),
                    SizedBox(height: 20.h),
                  ],

                  // Room/Station Info
                  if (match.stationNumber != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.device_tv, color: AppColors.neonBlue, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            '${AppStrings.roomStation.tr()}: ${match.stationNumber}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],

                  // Players Scoreboard Card
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Player 1
                        Expanded(
                          child: _buildPlayerScoreColumn(
                            name: match.player1Name ?? AppStrings.player1.tr(),
                            score: state.player1Score,
                            onIncrement: () => context.read<TournamentMatchCubit>().updatePlayer1Score(state.player1Score + 1),
                            onDecrement: () => context.read<TournamentMatchCubit>().updatePlayer1Score((state.player1Score - 1).clamp(0, 999)),
                            isEditable: match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled,
                          ),
                        ),

                        // VS Divider
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Text(
                            AppStrings.vs.tr(),
                            style: TextStyle(
                              color: AppColors.neonBlue,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ),

                        // Player 2
                        Expanded(
                          child: _buildPlayerScoreColumn(
                            name: match.player2Name ?? AppStrings.player2.tr(),
                            score: state.player2Score,
                            onIncrement: () => context.read<TournamentMatchCubit>().updatePlayer2Score(state.player2Score + 1),
                            onDecrement: () => context.read<TournamentMatchCubit>().updatePlayer2Score((state.player2Score - 1).clamp(0, 999)),
                            isEditable: match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Proof Screenshot Section
                  if (match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.uploadMatchProof.tr(),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),

                    if (state.proofFile != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: Image.file(
                              state.proofFile!,
                              height: 180.h,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.7),
                              child: IconButton(
                                icon: Icon(Icons.close, color: Colors.white, size: 18.sp),
                                onPressed: () => context.read<TournamentMatchCubit>().setProofFile(null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickProofImage(ImageSource.gallery),
                              borderRadius: BorderRadius.circular(12.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedBackground,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppColors.borderDefault),
                                ),
                                child: Column(
                                  children: [
                                    Icon(TablerIcons.photo, color: AppColors.neonBlue, size: 28.sp),
                                    SizedBox(height: 6.h),
                                    Text(AppStrings.gallery.tr(), style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickProofImage(ImageSource.camera),
                              borderRadius: BorderRadius.circular(12.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedBackground,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppColors.borderDefault),
                                ),
                                child: Column(
                                  children: [
                                    Icon(TablerIcons.camera, color: AppColors.neonPurple, size: 28.sp),
                                    SizedBox(height: 6.h),
                                    Text(AppStrings.camera.tr(), style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 28.h),

                    // Submit Result Button
                    AppButton(
                      buttonConfig: ButtonConfig.gradient(
                        gradient: AppColors.primaryGradient,
                        glowColor: AppColors.neonBlueAlt,
                        width: double.infinity,
                      ),
                      content: ButtonContent(label: AppStrings.submitResult.tr()),
                      behavior: TapBehavior(
                        isLoading: state.isSubmittingResult,
                        onTap: () => context.read<TournamentMatchCubit>().submitResult(),
                      ),
                    ),
                  ],

                  // Action Buttons for Pending Confirmation State
                  if (match.status == MatchStatus.pendingConfirmation) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            buttonConfig: ButtonConfig.gradient(
                              gradient: AppColors.primaryGradient,
                              glowColor: AppColors.neonBlueAlt,
                            ),
                            content: ButtonContent(label: AppStrings.confirmResult.tr()),
                            behavior: TapBehavior(
                              isLoading: state.isConfirmingResult,
                              onTap: () => context.read<TournamentMatchCubit>().confirmResult(),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AppButton(
                            buttonConfig: ButtonConfig(
                              backgroundColor: AppColors.danger,
                            ),
                            content: ButtonContent(label: AppStrings.disputeResult.tr()),
                            behavior: TapBehavior(
                              isLoading: state.isSubmittingDispute,
                              onTap: () => _showDisputeDialog(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerScoreColumn({
    required String name,
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required bool isEditable,
  }) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 12.h),

        // Score Box with Controls
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.mutedBackground,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              if (isEditable) ...[
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(TablerIcons.minus, color: AppColors.textSecondary, size: 20.sp),
                      onPressed: onDecrement,
                    ),
                    IconButton(
                      icon: Icon(TablerIcons.plus, color: AppColors.neonBlue, size: 20.sp),
                      onPressed: onIncrement,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
