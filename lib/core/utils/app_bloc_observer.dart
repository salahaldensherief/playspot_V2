import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/utils/app_logger.dart';

/// A global [BlocObserver] that logs all Cubit/Bloc lifecycle events
/// and maintains in-memory session statistics for debugging and leak detection.
class AppBlocObserver extends BlocObserver {
  static final AppBlocObserver instance = AppBlocObserver._internal();

  factory AppBlocObserver() => instance;

  AppBlocObserver._internal();

  // In-memory statistics (active in kDebugMode only)
  final Map<int, String> _activeBlocs = {}; // hashCode -> runtimeType name
  final Map<String, int> _changeCounts = {}; // Cubit type -> total onChange count
  final Map<String, int> _errorCounts = {}; // Cubit type -> total onError count

  String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    _activeBlocs[bloc.hashCode] = type;

    AppLogger.debug('[BLOC][CREATE] $type at ${_timestamp()} (Active: ${_activeBlocs.length})');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    _changeCounts[type] = (_changeCounts[type] ?? 0) + 1;

    final currentType = change.currentState.runtimeType;
    final nextType = change.nextState.runtimeType;

    AppLogger.debug('[BLOC][CHANGE] $type: $currentType ➔ $nextType at ${_timestamp()}');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    AppLogger.debug('[BLOC][EVENT] $type: ${event.runtimeType} at ${_timestamp()}');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    final currentType = transition.currentState.runtimeType;
    final nextType = transition.nextState.runtimeType;
    final eventType = transition.event.runtimeType;

    AppLogger.debug('[BLOC][TRANSITION] $type: $currentType ➔ $eventType ➔ $nextType at ${_timestamp()}');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    _errorCounts[type] = (_errorCounts[type] ?? 0) + 1;

    AppLogger.error('[BLOC][ERROR] $type: $error at ${_timestamp()}', error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (!kDebugMode) return;

    final type = bloc.runtimeType.toString();
    _activeBlocs.remove(bloc.hashCode);

    AppLogger.debug('[BLOC][CLOSE] $type at ${_timestamp()} (Active: ${_activeBlocs.length})');
  }

  /// Prints an in-memory summary of active Cubits/Blocs, total changes, and errors.
  static void printSummary() {
    if (!kDebugMode) return;

    final observer = instance;
    final buffer = StringBuffer();
    buffer.writeln('\n=================== 📊 BLOC / CUBIT MONITOR SUMMARY ===================');
    buffer.writeln('⏰ Timestamp: ${observer._timestamp()}');
    buffer.writeln('🟢 Active Blocs/Cubits Count: ${observer._activeBlocs.length}');

    if (observer._activeBlocs.isNotEmpty) {
      buffer.writeln('📋 Active Instances:');
      final groupedActive = <String, int>{};
      for (final name in observer._activeBlocs.values) {
        groupedActive[name] = (groupedActive[name] ?? 0) + 1;
      }
      groupedActive.forEach((name, count) {
        buffer.writeln('   - $name: $count instance(s)');
      });
    } else {
      buffer.writeln('   (No active Cubits)');
    }

    buffer.writeln('\n⚡ Change Counts (Rebuild Frequency):');
    if (observer._changeCounts.isNotEmpty) {
      final sortedChanges = observer._changeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedChanges) {
        buffer.writeln('   - ${entry.key}: ${entry.value} change(s)');
      }
    } else {
      buffer.writeln('   (No changes recorded)');
    }

    buffer.writeln('\n🔴 Error Counts:');
    if (observer._errorCounts.isNotEmpty) {
      observer._errorCounts.forEach((name, count) {
        buffer.writeln('   - $name: $count error(s)');
      });
    } else {
      buffer.writeln('   (No errors recorded)');
    }

    buffer.writeln('========================================================================\n');
    AppLogger.debug(buffer.toString());
  }
}
