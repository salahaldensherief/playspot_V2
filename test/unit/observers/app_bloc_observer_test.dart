import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/utils/app_bloc_observer.dart';

class TestCubit extends Cubit<int> {
  TestCubit() : super(0);

  void increment() => emit(state + 1);
  void triggerError() => addError(Exception('Test Error'));
}

void main() {
  late AppBlocObserver observer;

  setUp(() {
    observer = AppBlocObserver();
  });

  test('AppBlocObserver tracks lifecycle, changes, and summary', () {
    final cubit = TestCubit();
    observer.onCreate(cubit);

    cubit.increment();
    observer.onChange(cubit, Change(currentState: 0, nextState: 1));

    cubit.triggerError();
    observer.onError(cubit, Exception('Test Error'), StackTrace.current);

    AppBlocObserver.printSummary();

    observer.onClose(cubit);
    cubit.close();
  });
}
