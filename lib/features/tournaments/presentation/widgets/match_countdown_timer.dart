import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/time/deadline_countdown.dart';

class MatchCountdownTimer extends StatelessWidget {
  final DateTime deadline;
  final VoidCallback? onExpired;

  const MatchCountdownTimer({
    super.key,
    required this.deadline,
    this.onExpired,
  });

  @override
  Widget build(BuildContext context) => DeadlineCountdown(
    deadline: deadline,
    onExpired: onExpired,
    builder: _buildRemaining,
  );

  Widget _buildRemaining(BuildContext context, Duration remaining) {
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            TablerIcons.clock_hour_4,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                text: AppStrings.autoApprovalTimer.tr(),
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
