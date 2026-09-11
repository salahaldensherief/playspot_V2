import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../art_core/theme/app_colors.dart';

class MatchCountdownTimer extends StatefulWidget {
  final DateTime deadline;
  final VoidCallback? onExpired;

  const MatchCountdownTimer({
    super.key,
    required this.deadline,
    this.onExpired,
  });

  @override
  State<MatchCountdownTimer> createState() => _MatchCountdownTimerState();
}

class _MatchCountdownTimerState extends State<MatchCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _updateRemaining();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final diff = widget.deadline.toUtc().difference(now);

    if (diff.isNegative) {
      _timer?.cancel();
      if (mounted) {
        setState(() => _remaining = Duration.zero);
        widget.onExpired?.call();
      }
    } else {
      if (mounted) {
        setState(() => _remaining = diff);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.5), width: 1.2),
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
              Text(
                'autoApprovalTimer'.tr(),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
