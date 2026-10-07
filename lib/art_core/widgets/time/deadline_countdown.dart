import 'package:flutter/material.dart';

import 'app_clock.dart';

class DeadlineCountdown extends StatelessWidget {
  final DateTime deadline;
  final VoidCallback? onExpired;
  final Widget Function(BuildContext, Duration) builder;

  const DeadlineCountdown({
    super.key,
    required this.deadline,
    required this.builder,
    this.onExpired,
  });

  @override
  Widget build(BuildContext context) => AppClock(
    child: _DeadlineView(
      deadline: deadline,
      onExpired: onExpired,
      builder: builder,
    ),
  );
}

class _DeadlineView extends StatefulWidget {
  final DateTime deadline;
  final VoidCallback? onExpired;
  final Widget Function(BuildContext, Duration) builder;

  const _DeadlineView({
    required this.deadline,
    required this.builder,
    this.onExpired,
  });

  @override
  State<_DeadlineView> createState() => _DeadlineViewState();
}

class _DeadlineViewState extends State<_DeadlineView> {
  ValueListenable<DateTime>? _clock;
  DateTime? _notifiedDeadline;
  bool _enabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.of(context);
    final clock = AppClock.of(context);
    if (_clock != clock) {
      _clock?.removeListener(_notifyExpiry);
      _clock = clock;
      clock.addListener(_notifyExpiry);
    }
    _scheduleExpiryCheck();
  }

  @override
  void didUpdateWidget(covariant _DeadlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _notifiedDeadline = null;
    _scheduleExpiryCheck();
  }

  void _scheduleExpiryCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyExpiry();
    });
  }

  void _notifyExpiry() {
    if (!_enabled ||
        widget.onExpired == null ||
        _notifiedDeadline == widget.deadline)
      return;
    final now = _clock!.value;
    if (now.isBefore(widget.deadline)) return;
    _notifiedDeadline = widget.deadline;
    widget.onExpired!();
  }

  @override
  void dispose() {
    _clock?.removeListener(_notifyExpiry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppClockBuilder(
    builder: (context, now, child) {
      final remaining = widget.deadline.difference(now);
      return widget.builder(
        context,
        remaining.isNegative ? Duration.zero : remaining,
      );
    },
  );
}
