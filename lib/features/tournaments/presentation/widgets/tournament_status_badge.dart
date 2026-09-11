import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../art_core/theme/app_colors.dart';
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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: config.borderColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
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
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: config.textColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(BuildContext context, TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return _BadgeConfig(
          label: 'draft'.tr(),
          backgroundColor: AppColors.textSecondary.withOpacity(0.15),
          borderColor: AppColors.textSecondary,
          dotColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
        );
      case TournamentStatus.published:
        return _BadgeConfig(
          label: 'published'.tr(),
          backgroundColor: AppColors.neonBlue.withOpacity(0.15),
          borderColor: AppColors.neonBlue,
          dotColor: AppColors.neonBlue,
          textColor: AppColors.neonBlue,
        );
      case TournamentStatus.registrationOpen:
        return _BadgeConfig(
          label: 'registrationOpen'.tr(),
          backgroundColor: AppColors.neonBlue.withOpacity(0.15),
          borderColor: AppColors.neonBlue,
          dotColor: AppColors.neonBlue,
          textColor: AppColors.neonBlue,
        );
      case TournamentStatus.registrationClosed:
        return _BadgeConfig(
          label: 'registrationClosed'.tr(),
          backgroundColor: AppColors.warning.withOpacity(0.15),
          borderColor: AppColors.warning,
          dotColor: AppColors.warning,
          textColor: AppColors.warning,
        );
      case TournamentStatus.checkInOpen:
        return _BadgeConfig(
          label: 'checkInOpen'.tr(),
          backgroundColor: AppColors.warning.withOpacity(0.15),
          borderColor: AppColors.warning,
          dotColor: AppColors.warning,
          textColor: AppColors.warning,
        );
      case TournamentStatus.checkInClosed:
        return _BadgeConfig(
          label: 'checkInClosed'.tr(),
          backgroundColor: AppColors.textSecondary.withOpacity(0.15),
          borderColor: AppColors.textSecondary,
          dotColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
        );
      case TournamentStatus.drawCompleted:
        return _BadgeConfig(
          label: 'drawCompleted'.tr(),
          backgroundColor: AppColors.neonPurple.withOpacity(0.15),
          borderColor: AppColors.neonPurple,
          dotColor: AppColors.neonPurple,
          textColor: AppColors.neonPurple,
        );
      case TournamentStatus.inProgress:
        return _BadgeConfig(
          label: 'tournamentInProgress'.tr(),
          backgroundColor: AppColors.neonPurple.withOpacity(0.15),
          borderColor: AppColors.neonPurple,
          dotColor: AppColors.neonPurple,
          textColor: AppColors.neonPurple,
        );
      case TournamentStatus.completed:
        return _BadgeConfig(
          label: 'tournamentCompleted'.tr(),
          backgroundColor: AppColors.success.withOpacity(0.15),
          borderColor: AppColors.success,
          dotColor: AppColors.success,
          textColor: AppColors.success,
        );
      case TournamentStatus.cancelled:
        return _BadgeConfig(
          label: 'tournamentCancelled'.tr(),
          backgroundColor: AppColors.danger.withOpacity(0.15),
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
