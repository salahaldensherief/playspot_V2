import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'timer_widget.dart';

class TimerSection extends StatefulWidget {
  const TimerSection({super.key});

  @override
  State<TimerSection> createState() => _TimerSectionState();
}

class _TimerSectionState extends State<TimerSection> {
  Timer? _ticker;
  final ValueNotifier<Duration> _remainingNotifier = ValueNotifier(Duration.zero);
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _initTimerData();
  }

  void _initTimerData() {
    final state = context.read<ActiveSessionCubit>().state;
    if (state.session != null) {
      _startTime = state.session!.startTime;
      _endTime = state.session!.endTime;
      _updateRemaining();
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _startTime != null && _endTime != null) {
        _updateRemaining();
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (_startTime != null && _endTime != null) {
      if (now.isBefore(_startTime!)) {
        _remainingNotifier.value = _startTime!.difference(now);
      } else {
        _remainingNotifier.value = _endTime!.difference(now);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remainingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveSessionCubit, ActiveSessionState>(
      listenWhen: (prev, curr) =>
          prev.session?.startTime != curr.session?.startTime ||
          prev.session?.endTime != curr.session?.endTime,
      listener: (context, state) {
        if (state.session != null) {
          _startTime = state.session!.startTime;
          _endTime = state.session!.endTime;
          _updateRemaining();
        }
      },
      buildWhen: (prev, curr) =>
          prev.session?.bookingId != curr.session?.bookingId ||
          prev.session?.endTime != curr.session?.endTime ||
          prev.session?.startTime != curr.session?.startTime ||
          prev.session?.extensionStatus != curr.session?.extensionStatus,
      builder: (context, state) {
        if (state.session == null) return const SizedBox.shrink();

        final session = state.session!;
        _startTime = session.startTime;
        _endTime = session.endTime;

        return RepaintBoundary(
          child: ValueListenableBuilder<Duration>(
            valueListenable: _remainingNotifier,
            builder: (context, remaining, child) {
              final now = DateTime.now();
              final currentStart = _startTime ?? session.startTime;
              final currentEnd = _endTime ?? session.endTime;
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
