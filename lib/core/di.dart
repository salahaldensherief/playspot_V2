import 'package:get_it/get_it.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/features/auth/presetation/forgot_password/forgot_password_cubit.dart';
import 'package:playspot/features/auth/presetation/signin/signin_cubit.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/data/data_source/remote/auth_remote_data_source.dart';
import '../features/auth/data/repos/auth_repos.dart';
import '../features/booking/data/data_source/remote/booking_remote_data_source.dart';
import '../features/booking/data/repos/booking_repo.dart';
import '../features/checkout/presentation/checkout_cubit.dart';
import '../features/home/data/data_source/remote/home_remote_data_source.dart';
import '../features/home/data/repos/home_repos.dart';
import '../features/home/presentation/home_cubit.dart';
import '../features/lounge_details/data/data_source/remote/lounge_details_remote_data_source.dart';
import '../features/lounge_details/data/repos/lounge_details_repo.dart';
import '../features/lounge_details/presentation/lounge_details_cubit.dart';
import '../features/my_bookings/data/data_source/remote/my_bookings_remote_data_source.dart';
import '../features/my_bookings/data/repos/my_bookings_repo.dart';
import '../features/my_bookings/presentation/my_bookings_cubit.dart';
import '../features/profile/data/data_source/remote/profile_remote_data_source.dart';
import '../features/profile/data/repos/profile_repo.dart';
import '../features/profile/presentation/edit_profile/edit_profile_cubit.dart';
import '../features/profile/presentation/profile_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await PreferenceManager.init();
  sl.registerLazySingleton(() => PreferenceManager());

  _initAuth();
  _initHome();
  _initLoungeDetails();
  _initBooking();
  _initCheckout();
  _initMyBookings();
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
}

void _initLoungeDetails() {
  sl.registerLazySingleton<LoungeDetailsRemoteDataSource>(
    () => LoungeDetailsRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<LoungeDetailsRepository>(
    () => LoungeDetailsRepositoryImpl(sl()),
  );

  sl.registerFactory<LoungeDetailsCubit>(
    () => LoungeDetailsCubit(sl(), sl(), sl()),
  );
}

void _initBooking() {
  sl.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );
}

void _initCheckout() {
  sl.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(sl()),
  );
}

void _initMyBookings() {
  sl.registerLazySingleton<MyBookingsRemoteDataSource>(
    () => MyBookingsRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<MyBookingsRepository>(
    () => MyBookingsRepositoryImpl(sl()),
  );

  sl.registerFactory<MyBookingsCubit>(
    () => MyBookingsCubit(sl()),
  );
}

void _initProfile() {
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(sl(), sl()),
  );
  sl.registerFactory<EditProfileCubit>(
    () => EditProfileCubit(sl()),
  );
}
