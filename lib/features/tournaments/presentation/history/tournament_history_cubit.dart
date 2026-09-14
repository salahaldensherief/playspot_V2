import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/usecases/get_user_tournament_history_usecase.dart';
import 'tournament_history_state.dart';

class TournamentHistoryCubit extends Cubit<TournamentHistoryState> {
  final GetUserTournamentHistoryUseCase _getUserTournamentHistoryUseCase;

  TournamentHistoryCubit(this._getUserTournamentHistoryUseCase)
      : super(const TournamentHistoryState());

  Future<void> loadHistory() async {
    emit(state.copyWith(status: TournamentHistoryStatus.loading));

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      emit(state.copyWith(
        status: TournamentHistoryStatus.failure,
        errorMessage: 'User not logged in',
      ));
      return;
    }

    final result = await _getUserTournamentHistoryUseCase(userId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: TournamentHistoryStatus.failure,
        errorMessage: failure.message,
      )),
      (participations) => emit(state.copyWith(
        status: TournamentHistoryStatus.success,
        participations: participations,
      )),
    );
  }
}
