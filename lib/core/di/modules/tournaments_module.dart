import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart';
import '../../../features/tournaments/data/repositories/tournaments_repository_impl.dart';
import '../../../features/tournaments/domain/repositories/tournaments_repository.dart';
import '../../../features/tournaments/domain/usecases/check_in_participant_usecase.dart';
import '../../../features/tournaments/domain/usecases/get_tournament_details_usecase.dart';
import '../../../features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../../../features/tournaments/domain/usecases/register_tournament_usecase.dart';
import '../../../features/tournaments/domain/usecases/submit_match_result_usecase.dart';
import '../../../features/tournaments/domain/usecases/submit_tournament_payment_usecase.dart';
import '../../../features/tournaments/domain/usecases/watch_tournament_matches_usecase.dart';
import '../../../features/tournaments/domain/usecases/withdraw_tournament_usecase.dart';
import '../../../features/tournaments/domain/usecases/get_user_tournament_history_usecase.dart';
import '../../../features/tournaments/presentation/tournaments_feed/tournaments_feed_cubit.dart';
import '../../../features/tournaments/presentation/tournament_details/tournament_details_cubit.dart';
import '../../../features/tournaments/presentation/live_match/tournament_match_cubit.dart';
import '../../../features/tournaments/presentation/history/tournament_history_cubit.dart';
import '../../di.dart';

void initTournamentsModule() {
  // Remote Data Source
  sl.registerLazySingleton<TournamentsRemoteDataSource>(
    () => TournamentsRemoteDataSourceImpl(Supabase.instance.client),
  );

  // Repository
  sl.registerLazySingleton<TournamentsRepository>(
    () => TournamentsRepositoryImpl(sl()),
  );

  // UseCases
  sl.registerLazySingleton(() => GetTournamentsUseCase(sl()));
  sl.registerLazySingleton(() => GetTournamentDetailsUseCase(sl()));
  sl.registerLazySingleton(() => RegisterTournamentUseCase(sl()));
  sl.registerLazySingleton(() => SubmitTournamentPaymentUseCase(sl()));
  sl.registerLazySingleton(() => CheckInParticipantUseCase(sl()));
  sl.registerLazySingleton(() => WatchTournamentMatchesUseCase(sl()));
  sl.registerLazySingleton(() => SubmitMatchResultUseCase(sl()));
  sl.registerLazySingleton(() => WithdrawTournamentUseCase(sl()));
  sl.registerLazySingleton(() => GetUserTournamentHistoryUseCase(sl()));

  // Cubits (Factory per screen route creation)
  sl.registerFactory<TournamentsFeedCubit>(
    () => TournamentsFeedCubit(sl(), sl(), sl()),
  );

  sl.registerFactory<TournamentDetailsCubit>(
    () => TournamentDetailsCubit(sl(), sl(), sl(), sl(), sl(), sl()),
  );

  sl.registerFactory<TournamentMatchCubit>(
    () => TournamentMatchCubit(sl(), sl(), sl()),
  );

  sl.registerFactory<TournamentHistoryCubit>(
    () => TournamentHistoryCubit(sl()),
  );
}
