import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/active_session/data/datasources/remote/active_session_remote_data_source.dart';
import '../../../features/active_session/data/repositories/active_session_repository_impl.dart';
import '../../../features/active_session/domain/repositories/active_session_repository.dart';
import '../../../features/active_session/domain/usecases/extend_session_time_usecase.dart';
import '../../../features/active_session/domain/usecases/get_active_lounge_requests_page_usecase.dart';
import '../../../features/active_session/domain/usecases/get_active_session_usecase.dart';
import '../../../features/active_session/domain/usecases/get_lounge_menu_usecase.dart';
import '../../../features/active_session/domain/usecases/place_session_order_usecase.dart';
import '../../../features/active_session/domain/usecases/request_session_extension_usecase.dart';
import '../../../features/active_session/domain/usecases/request_staff_assistance_usecase.dart';
import '../../../features/active_session/domain/usecases/stream_active_session_usecase.dart';
import '../../../features/active_session/domain/usecases/submit_lounge_review_usecase.dart';
import '../../../features/active_session/domain/usecases/watch_user_active_session_usecase.dart';
import '../../../features/active_session/presentation/active_session_cubit.dart';
import '../../datasources/local/app_cache_local_data_source.dart';
import '../../di.dart';

void initActiveSessionModule() {
  // Remote Data Source
  sl.registerLazySingleton<ActiveSessionRemoteDataSource>(
    () => ActiveSessionRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  // Repository
  sl.registerLazySingleton<ActiveSessionRepository>(
    () => ActiveSessionRepositoryImpl(
      sl<ActiveSessionRemoteDataSource>(),
      sl<AppCacheLocalDataSource>(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetActiveSessionUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => WatchUserActiveSessionUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => StreamActiveSessionUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => ExtendSessionTimeUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => RequestSessionExtensionUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => PlaceSessionOrderUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => GetLoungeMenuUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => RequestStaffAssistanceUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => SubmitLoungeReviewUseCase(sl<ActiveSessionRepository>()));
  sl.registerLazySingleton(() => GetActiveLoungeRequestsPageUseCase(sl<ActiveSessionRepository>()));

  // Cubit
  sl.registerFactory(
    () => ActiveSessionCubit(
      getActiveSessionUseCase: sl<GetActiveSessionUseCase>(),
      watchUserActiveSessionUseCase: sl<WatchUserActiveSessionUseCase>(),
      streamActiveSessionUseCase: sl<StreamActiveSessionUseCase>(),
      extendSessionTimeUseCase: sl<ExtendSessionTimeUseCase>(),
      requestSessionExtensionUseCase: sl<RequestSessionExtensionUseCase>(),
      placeSessionOrderUseCase: sl<PlaceSessionOrderUseCase>(),
      getLoungeMenuUseCase: sl<GetLoungeMenuUseCase>(),
      requestStaffAssistanceUseCase: sl<RequestStaffAssistanceUseCase>(),
      submitLoungeReviewUseCase: sl<SubmitLoungeReviewUseCase>(),
    ),
  );
}
