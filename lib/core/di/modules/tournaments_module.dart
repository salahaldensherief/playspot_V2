import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart';
import '../../../features/tournaments/data/repositories/tournaments_repository_impl.dart';
import '../../../features/tournaments/domain/repositories/tournaments_repository.dart';
import '../../../features/tournaments/presentation/tournaments_feed/tournaments_feed_cubit.dart';
import '../../../features/tournaments/presentation/tournament_details/tournament_details_cubit.dart';
import '../../../features/tournaments/presentation/live_match/tournament_match_cubit.dart';
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

  // Cubits (Factory per screen route creation)
  sl.registerFactory<TournamentsFeedCubit>(
    () => TournamentsFeedCubit(sl()),
  );

  sl.registerFactory<TournamentDetailsCubit>(
    () => TournamentDetailsCubit(sl()),
  );

  sl.registerFactory<TournamentMatchCubit>(
    () => TournamentMatchCubit(sl()),
  );
}
