import 'package:playspot/features/notifications/data/data_source/remote/notifications_remote_data_source.dart';
import 'package:playspot/features/notifications/data/repos/notifications_repository.dart';
import 'package:playspot/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../di.dart';

void initNotificationsModule() {
  // Data sources
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  // Repository
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
  );

  // Cubit
  sl.registerLazySingleton(() => NotificationsCubit(sl<NotificationsRepository>()));
}
