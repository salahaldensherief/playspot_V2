import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'timer_widget.dart';

class TimerSection extends StatelessWidget {
  const TimerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) => prev.remainingTime != curr.remainingTime || prev.session?.endTime != curr.session?.endTime,
      builder: (context, state) {
        if (state.session == null) return const SizedBox.shrink();
        
        final session = state.session!;
        final totalDuration = session.endTime.difference(session.startTime);
        final progress = totalDuration.inSeconds > 0 
            ? state.remainingTime.inSeconds / totalDuration.inSeconds 
            : 0.0;
        
        Color statusColor = AppColors.success;
        if (session.isOvertime) {
          statusColor = AppColors.danger;
        } else if (session.isExpiringSoon) {
          statusColor = AppColors.warning;
        }

        return TimerWidget(
          remaining: state.remainingTime,
          progress: progress.clamp(0.0, 1.0),
          statusColor: statusColor,
        );
      },
    );
  }
}
