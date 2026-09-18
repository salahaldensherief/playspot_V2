import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/utils/app_logger.dart';

class AppBlocObserver extends BlocObserver {
  String _getStateSummary(dynamic state) {
    try {
      final status = (state as dynamic).status;
      if (status != null) return '$status';
    } catch (_) {}
    return '${state.runtimeType}';
  }

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    AppLogger.debug('🟢 CREATED: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (bloc.runtimeType.toString().contains('ActiveSession')) return;

    final currentSummary = _getStateSummary(change.currentState);
    final nextSummary = _getStateSummary(change.nextState);
    AppLogger.debug('⚡ CHANGE [${bloc.runtimeType}]: $currentSummary ➔ $nextSummary');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    AppLogger.error('🔴 ERROR in ${bloc.runtimeType}', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    AppLogger.debug('🔴 CLOSED: ${bloc.runtimeType}');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    AppLogger.debug('📌 EVENT [${bloc.runtimeType}]: ${event.runtimeType}');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (bloc.runtimeType.toString().contains('ActiveSession')) return;

    final currentSummary = _getStateSummary(transition.currentState);
    final nextSummary = _getStateSummary(transition.nextState);
    AppLogger.debug('🔄 TRANSITION [${bloc.runtimeType}]: $currentSummary ➔ ${transition.event.runtimeType} ➔ $nextSummary');
  }
}
