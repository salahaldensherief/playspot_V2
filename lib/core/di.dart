import 'package:get_it/get_it.dart';
import 'package:playspot/features/auth/presetation/signin/signin_cubit.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/data_source/remote/auth_remote_data_source.dart';
import '../features/auth/data/repos/auth_repos.dart';

final sl = GetIt.instance;

Future<void> init()  async {
  _initAuth();
}

// ─── Supabase ─────────────────────────────────────────────────
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

// ─── Auth ─────────────────────────────────────────────────────
void _initAuth() {

  // Data Source
  sl.registerLazySingleton<AuthRemoteSource>(
        () => AuthRemoteSourceImpl(),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(sl()),
  );

  // Login Cubit
  sl.registerFactory<SignInCubit>(
        () => SignInCubit(sl()),
  );

  // Signup Cubit
  sl.registerFactory<SignupCubit>(
        () => SignupCubit(sl()),
  );
}