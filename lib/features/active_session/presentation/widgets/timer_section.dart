import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/time/app_clock.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'timer_widget.dart';

class TimerSection extends StatelessWidget {
  const TimerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.session?.bookingId != curr.session?.bookingId ||
          prev.session?.endTime != curr.session?.endTime ||
          prev.session?.startTime != curr.session?.startTime,
      builder: (context, state) {
        final session = state.session;
        if (session == null) return const SizedBox.shrink();

        return RepaintBoundary(
          child: AppClockBuilder(
            builder: (context, now, child) {
              final currentStart = session.startTime;
              final currentEnd = session.endTime;
              final remaining = now.isBefore(currentStart)
                  ? currentStart.difference(now)
                  : currentEnd.difference(now);
              final hasStarted = !now.isBefore(currentStart);

              if (!hasStarted) {
                return TimerWidget(
                  remaining: remaining,
                  progress: 1.0,
                  statusColor: AppColors.neonBlue,
                  labelOverride: AppStrings.startsIn.tr().toUpperCase(),
                );
              }

              final totalDuration = currentEnd.difference(currentStart);
              final progress = totalDuration.inSeconds > 0
                  ? remaining.inSeconds / totalDuration.inSeconds
                  : 0.0;

              Color statusColor = AppColors.success;
              if (now.isAfter(currentEnd)) {
                statusColor = AppColors.danger;
              } else if (currentEnd.difference(now).inMinutes <= 15) {
                statusColor = AppColors.warning;
              }

              return TimerWidget(
                remaining: remaining,
                progress: progress.clamp(0.0, 1.0),
                statusColor: statusColor,
              );
            },
          ),
        );
      },
    );
  }
}
