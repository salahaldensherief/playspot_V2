import '../../../features/auth/data/data_source/local/auth_local_data_source.dart';
import '../../../features/auth/data/data_source/remote/auth_remote_data_source.dart';
import '../../../features/auth/data/repos/auth_repos.dart';
import '../../../features/auth/presetation/forgot_password/forgot_password_cubit.dart';
import '../../../features/auth/presetation/signin/signin_cubit.dart';
import '../../../features/auth/presetation/signup/signup_cubit.dart';
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
