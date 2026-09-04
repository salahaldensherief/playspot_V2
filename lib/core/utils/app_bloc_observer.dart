import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    log('CREATED: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (bloc.runtimeType.toString().contains('ActiveSession')) return;
    log('CHANGE: ${bloc.runtimeType} | Current: ${change.currentState} | Next: ${change.nextState}');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    log('ERROR in ${bloc.runtimeType}: $error', stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    log('CLOSED: ${bloc.runtimeType}');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    log('EVENT: ${bloc.runtimeType} | Event: $event');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (bloc.runtimeType.toString().contains('ActiveSession')) return;
    log('TRANSITION: ${bloc.runtimeType} | Current: ${transition.currentState} | Event: ${transition.event} | Next: ${transition.nextState}');
  }
}
