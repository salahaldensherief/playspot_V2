import 'package:get_it/get_it.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/features/auth/presetation/forgot_password/forgot_password_cubit.dart';
import 'package:playspot/features/auth/presetation/signin/signin_cubit.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/data_source/remote/auth_remote_data_source.dart';
import '../features/auth/data/repos/auth_repos.dart';
import '../features/home/data/data_source/remote/home_remote_data_source.dart';
import '../features/home/data/repos/home_repos.dart';
import '../features/home/presentation/home_cubit.dart';
import '../features/lounge_details/presentation/lounge_details_cubit.dart';

import '../features/profile/presentation/profile_cubit.dart';

final sl = GetIt.instance;

Future<void> init()  async {
  await PreferenceManager.init();
  sl.registerLazySingleton(() => PreferenceManager());

  _initAuth();
  _initHome();
  _initProfile();
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://tgpdexoitemmpruepgyt.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRncGRleG9pdGVtbXBydWVwZ3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjYyNzYsImV4cCI6MjA5NDI0MjI3Nn0.i5ekdw4CkWh97-BGWzCRQZ4c9bIKWIo2vD-Ev58BVC4',
  );

  sl.registerLazySingleton<SupabaseClient>(
        () => Supabase.instance.client,
  );
}
void _initAuth() {

  sl.registerLazySingleton<AuthRemoteSource>(
        () => AuthRemoteSourceImpl(),
  );

  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(sl(), sl()),
  );

  sl.registerFactory<SignInCubit>(
        () => SignInCubit(sl()),
  );

  sl.registerFactory<SignupCubit>(
        () => SignupCubit(sl()),
  );

  sl.registerLazySingleton<ForgotPasswordCubit>(
        () => ForgotPasswordCubit(sl()),
  );
}

void _initHome() {
  sl.registerLazySingleton<HomeRemoteDataSource>(
        () => HomeRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<HomeRepository>(
        () => HomeRepositoryImpl(sl()),
  );

  sl.registerFactory<HomeCubit>(
        () => HomeCubit(sl()),
  );

  sl.registerFactory<LoungeDetailsCubit>(
        () => LoungeDetailsCubit(sl()),
  );
}

void _initProfile() {
  sl.registerFactory<ProfileCubit>(
    () => ProfileCubit(sl()),
  );
}
