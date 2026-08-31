import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/active_session/data/datasources/remote/active_session_remote_data_source.dart';
import '../../../features/active_session/domain/repositories/active_session_repository.dart';
import '../../../features/active_session/data/repositories/active_session_repository_impl.dart';
import '../../../features/active_session/presentation/active_session_cubit.dart';
import '../../di.dart';

void initActiveSessionModule() {
  // Remote Data Source
  sl.registerLazySingleton<ActiveSessionRemoteDataSource>(
    () => ActiveSessionRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  // Repository
  sl.registerLazySingleton<ActiveSessionRepository>(
    () => ActiveSessionRepositoryImpl(sl<ActiveSessionRemoteDataSource>()),
  );

  // Cubit
  sl.registerFactory(() => ActiveSessionCubit(sl<ActiveSessionRepository>()));
}
