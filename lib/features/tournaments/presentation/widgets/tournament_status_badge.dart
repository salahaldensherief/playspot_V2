import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../domain/entities/tournament_entity.dart';

class TournamentStatusBadge extends StatelessWidget {
  final TournamentStatus status;
  final bool compact;

  const TournamentStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getBadgeConfig(context, status);

    return GlassContainer(
      borderRadius: 12,
      blur: 8,
      borderOpacity: 0.35,
      borderColor: config.borderColor,
      color: config.backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(
              color: config.dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: config.dotColor,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AppText(
            text: config.label,
            color: config.textColor,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(BuildContext context, TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return _BadgeConfig(
          label: AppStrings.draft.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.6),
          borderColor: AppColors.textSecondary,
          dotColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
        );
      case TournamentStatus.published:
      case TournamentStatus.registrationOpen:
        return _BadgeConfig(
          label: AppStrings.registrationOpen.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.neonBlue,
          dotColor: AppColors.neonBlue,
          textColor: AppColors.neonBlue,
        );
      case TournamentStatus.registrationClosed:
        return _BadgeConfig(
          label: AppStrings.registrationClosed.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.warning,
          dotColor: AppColors.warning,
          textColor: AppColors.warning,
        );
      case TournamentStatus.checkInOpen:
        return _BadgeConfig(
          label: AppStrings.checkInOpen.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.warning,
          dotColor: AppColors.warning,
          textColor: AppColors.warning,
        );
      case TournamentStatus.checkInClosed:
        return _BadgeConfig(
          label: AppStrings.checkInClosed.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.textSecondary,
          dotColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
        );
      case TournamentStatus.drawCompleted:
      case TournamentStatus.inProgress:
        return _BadgeConfig(
          label: AppStrings.tournamentInProgress.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.neonPurple,
          dotColor: AppColors.neonPurple,
          textColor: AppColors.neonPurple,
        );
      case TournamentStatus.completed:
        return _BadgeConfig(
          label: AppStrings.tournamentCompleted.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.success,
          dotColor: AppColors.success,
          textColor: AppColors.success,
        );
      case TournamentStatus.cancelled:
        return _BadgeConfig(
          label: AppStrings.tournamentCancelled.tr(),
          backgroundColor: AppColors.black.withValues(alpha: 0.75),
          borderColor: AppColors.danger,
          dotColor: AppColors.danger,
          textColor: AppColors.danger,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color dotColor;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.dotColor,
    required this.textColor,
  });
}
