import '../../../features/auth/data/datasources/local/auth_local_data_source.dart';
import '../../../features/auth/data/datasources/remote/auth_remote_data_source.dart';
import '../../../features/auth/domain/repositories/auth_repo.dart';
import '../../../features/auth/data/repositories/auth_repo_impl.dart';
import '../../../features/auth/presentation/forgot_password_cubit.dart';
import '../../../features/auth/presentation/signin_cubit.dart';
import '../../../features/auth/presentation/signup_cubit.dart';
import '../../di.dart';

void initAuthModule() {
  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRemoteSource>(
    () => AuthRemoteSourceImpl(sl(), sl(), sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );

  // Cubits
  sl.registerFactory<SignInCubit>(() => SignInCubit(sl()));
  sl.registerFactory<SignupCubit>(() => SignupCubit(sl()));
  sl.registerLazySingleton<ForgotPasswordCubit>(() => ForgotPasswordCubit(sl()));
}
