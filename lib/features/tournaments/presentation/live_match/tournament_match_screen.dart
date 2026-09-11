import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
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

      if (picked != null) {
        if (mounted) {
          context.read<TournamentMatchCubit>().setProofFile(File(picked.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorPickingImage'.tr(args: ['$e']))),
      );
    }
  }

  void _showDisputeDialog() {
    _disputeReasonController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.danger),
        ),
        title: Text(
          'disputeResult'.tr(),
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'disputeReason'.tr(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _disputeReasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'enterDisputeReason'.tr(),
                hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 12),
                filled: true,
                fillColor: AppColors.mutedBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('close'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            buttonConfig: ButtonConfig(
              backgroundColor: AppColors.danger,
              width: 120,
            ),
            content: ButtonContent(label: 'disputeResult'.tr()),
            behavior: TapBehavior(
              onTap: () {
                if (_disputeReasonController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                context.read<TournamentMatchCubit>().disputeResult(_disputeReasonController.text.trim());
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
                'noResults'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
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
              'matchDetails'.tr(),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 20),
                  ],

                  // Room/Station Info
                  if (match.stationNumber != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(TablerIcons.device_tv, color: AppColors.neonBlue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${'roomStation'.tr()}: ${match.stationNumber}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Players Scoreboard Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Player 1
                        Expanded(
                          child: _buildPlayerScoreColumn(
                            name: match.player1Name ?? 'player1'.tr(),
                            score: state.player1Score,
                            onIncrement: () => context.read<TournamentMatchCubit>().updatePlayer1Score(state.player1Score + 1),
                            onDecrement: () => context.read<TournamentMatchCubit>().updatePlayer1Score(state.player1Score - 1),
                            isEditable: match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled,
                          ),
                        ),

                        // VS Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'vs'.tr(),
                            style: const TextStyle(
                              color: AppColors.neonBlue,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ),

                        // Player 2
                        Expanded(
                          child: _buildPlayerScoreColumn(
                            name: match.player2Name ?? 'player2'.tr(),
                            score: state.player2Score,
                            onIncrement: () => context.read<TournamentMatchCubit>().updatePlayer2Score(state.player2Score + 1),
                            onDecrement: () => context.read<TournamentMatchCubit>().updatePlayer2Score(state.player2Score - 1),
                            isEditable: match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Proof Screenshot Section
                  if (match.status == MatchStatus.inProgress || match.status == MatchStatus.scheduled) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'uploadMatchProof'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (state.proofFile != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              state.proofFile!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withOpacity(0.7),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
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
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderDefault),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(TablerIcons.photo, color: AppColors.neonBlue, size: 28),
                                    const SizedBox(height: 6),
                                    Text('gallery'.tr(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickProofImage(ImageSource.camera),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderDefault),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(TablerIcons.camera, color: AppColors.neonPurple, size: 28),
                                    const SizedBox(height: 6),
                                    Text('camera'.tr(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Submit Result Button
                    AppButton(
                      buttonConfig: ButtonConfig.gradient(
                        gradient: AppColors.primaryGradient,
                        glowColor: AppColors.neonBlueAlt,
                        width: double.infinity,
                      ),
                      content: ButtonContent(label: 'submitResult'.tr()),
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
                            content: ButtonContent(label: 'confirmResult'.tr()),
                            behavior: TapBehavior(
                              isLoading: state.isConfirmingResult,
                              onTap: () => context.read<TournamentMatchCubit>().confirmResult(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            buttonConfig: ButtonConfig(
                              backgroundColor: AppColors.danger,
                            ),
                            content: ButtonContent(label: 'disputeResult'.tr()),
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Score Box with Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.mutedBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: AppColors.neonBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              if (isEditable) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(TablerIcons.minus, color: AppColors.textSecondary, size: 20),
                      onPressed: onDecrement,
                    ),
                    IconButton(
                      icon: const Icon(TablerIcons.plus, color: AppColors.neonBlue, size: 20),
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
