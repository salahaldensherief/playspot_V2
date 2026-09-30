import 'package:bloc_test/bloc_test.dart';
import 'package:playspot/features/active_session/presentation/active_session_cubit.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';

class MockVisualSessionCubit extends MockCubit<ActiveSessionState>
    implements ActiveSessionCubit {}
