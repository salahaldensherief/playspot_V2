import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/active_session/presentation/active_session_cubit.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';

class ActiveSessionBanner extends StatefulWidget {
  const ActiveSessionBanner({super.key});

  @override
  State<ActiveSessionBanner> createState() => _ActiveSessionBannerState();
}

class _ActiveSessionBannerState extends State<ActiveSessionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.session != current.session,
      builder: (context, state) {
        if (state.status != ActiveSessionStatus.loaded || state.session == null) {
          return const SizedBox.shrink();
        }

        final session = state.session!;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: GestureDetector(
            onTap: () => context.pushNamed(RouterKeys.activeSession),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neonBlue.withValues(alpha: 0.15),
                    AppColors.cardBackground,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSizes.r16),
                border: Border.all(
                  color: AppColors.neonBlue.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Isolated Ticking Progress Arc
                  _SessionCircularProgress(
                    startTime: session.startTime,
                    endTime: session.endTime,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final scale = 1.0 + (_pulseController.value * 0.4);
                                final opacity = 1.0 - (_pulseController.value * 0.6);
                                return Container(
                                  width: 8.w,
                                  height: 8.h,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(alpha: opacity),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withValues(alpha: opacity * 0.8),
                                        blurRadius: 6 * scale,
                                        spreadRadius: 2 * scale,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 6.w),
                            AppText(
                              text: 'Live now',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        AppText(
                          text: '${session.loungeName} - ${session.deviceName}',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        // Isolated Ticking Text Subtree
                        _SessionCountdownText(
                          startTime: session.startTime,
                          endTime: session.endTime,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          text: 'Join',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          TablerIcons.arrow_right,
                          color: AppColors.black,
                          size: 14.sp,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Isolated sub-widget for 1-second ticker text (prevents rebuilding parent banner)
class _SessionCountdownText extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _SessionCountdownText({
    required this.startTime,
    required this.endTime,
  });

  @override
  State<_SessionCountdownText> createState() => _SessionCountdownTextState();
}

class _SessionCountdownTextState extends State<_SessionCountdownText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.endTime.difference(now);
    final remainingSeconds = remaining.inSeconds;
    final isExpired = remainingSeconds <= 0;

    String timeText = '';
    if (isExpired) {
      timeText = 'Session ended';
    } else {
      final hours = remaining.inHours;
      final mins = remaining.inMinutes % 60;
      final secs = remaining.inSeconds % 60;
      if (hours > 0) {
        timeText = '$hours h $mins m remaining';
      } else if (mins > 0) {
        timeText = '$mins m ${secs}s remaining';
      } else {
        timeText = '${secs}s remaining';
      }
    }

    return AppText(
      text: timeText,
      fontSize: 11.sp,
      color: AppColors.textSecondary,
    );
  }
}

/// Isolated sub-widget for 1-second circular progress indicator
class _SessionCircularProgress extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _SessionCircularProgress({
    required this.startTime,
    required this.endTime,
  });

  @override
  State<_SessionCircularProgress> createState() => _SessionCircularProgressState();
}

class _SessionCircularProgressState extends State<_SessionCircularProgress> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalDuration = widget.endTime.difference(widget.startTime).inSeconds;
    final remaining = widget.endTime.difference(now);
    final remainingSeconds = remaining.inSeconds;

    double progress = 0.0;
    if (totalDuration > 0) {
      progress = (remainingSeconds / totalDuration).clamp(0.0, 1.0);
    }

    return SizedBox(
      width: 48.w,
      height: 48.h,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          progress: progress,
          progressColor: AppColors.neonBlue,
          backgroundColor: AppColors.neonBlue.withValues(alpha: 0.15),
          strokeWidth: 3.0,
        ),
        child: Center(
          child: Icon(
            TablerIcons.device_gamepad_2,
            color: AppColors.neonBlue,
            size: 22.sp,
          ),
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background track
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc (-90 degrees start angle)
    const startAngle = -3.141592653589793 / 2;
    final sweepAngle = 2 * 3.141592653589793 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
