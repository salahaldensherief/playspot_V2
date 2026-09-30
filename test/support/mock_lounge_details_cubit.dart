import 'package:bloc_test/bloc_test.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';

class MockLoungeDetailsCubit extends MockCubit<LoungeDetailsState>
    implements LoungeDetailsCubit {}
