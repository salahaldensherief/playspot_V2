import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

class AppClock extends StatefulWidget {
  final Widget child;
  final DateTime Function()? clock;

  const AppClock({super.key, required this.child, this.clock});

  static ValueListenable<DateTime> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ClockScope>();
    assert(scope != null, 'AppClock is required above this context.');
    return scope!.now;
  }

  @override
  State<AppClock> createState() => _AppClockState();
}

class _AppClockState extends State<AppClock> with WidgetsBindingObserver {
  late final ValueNotifier<DateTime> _now;
  Timer? _timer;
  bool _visible = false;
  bool _resumed = true;
  bool _hasParentClock = false;

  DateTime _readClock() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _now = ValueNotifier(_readClock());
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    _hasParentClock =
        context.dependOnInheritedWidgetOfExactType<_ClockScope>() != null;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant AppClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) _now.value = _readClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  void _syncTimer() {
    if (!_visible || !_resumed || _hasParentClock) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _now.value = _readClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = _readClock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _hasParentClock
      ? widget.child
      : _ClockScope(now: _now, child: widget.child);
}

class AppClockBuilder extends StatelessWidget {
  final Widget Function(BuildContext, DateTime, Widget?) builder;
  final Widget? child;

  const AppClockBuilder({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ClockScope>();
    if (scope == null) {
      return AppClock(
        child: AppClockBuilder(builder: builder, child: child),
      );
    }
    if (!TickerMode.of(context)) {
      return builder(context, scope.now.value, child);
    }
    return ValueListenableBuilder<DateTime>(
      valueListenable: scope.now,
      builder: builder,
      child: child,
    );
  }
}

class _ClockScope extends InheritedWidget {
  final ValueNotifier<DateTime> now;

  const _ClockScope({required this.now, required super.child});

  @override
  bool updateShouldNotify(_ClockScope oldWidget) => oldWidget.now != now;
}
