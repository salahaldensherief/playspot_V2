import 'package:get_it/get_it.dart';
import 'package:playspot/features/auth/presetation/signin/signin_cubit.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/data_source/remote/auth_remote_data_source.dart';
import '../features/auth/data/repos/auth_repos.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await _initSupabase();
  _initAuth();
}

// ─── Supabase ─────────────────────────────────────────────────
Future<void> _initSupabase() async {
  await Supabase.initialize(
    url: 'https://tgpdexoitemmpruepgyt.supabase.co',
    anonKey:
    'YOUR_ANON_KEY',
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
  sl.registerFactory<LoginCubit>(
        () => LoginCubit(sl()),
  );

  // Signup Cubit
  sl.registerFactory<SignupCubit>(
        () => SignupCubit(sl()),
  );
}