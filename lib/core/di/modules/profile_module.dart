import 'package:get_it/get_it.dart';
import '../../../features/profile/data/datasources/remote/profile_remote_data_source.dart';
import '../../../features/profile/domain/repositories/profile_repository.dart';
import '../../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../../features/profile/presentation/edit_profile/edit_profile_cubit.dart';
import '../../../features/profile/presentation/profile/profile_cubit.dart';
import '../../../features/profile/presentation/settings/notification_settings_cubit.dart';

final sl = GetIt.instance;

void initProfileModule() {
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl(), sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(sl(), sl()),
  );
  sl.registerFactory<EditProfileCubit>(
    () => EditProfileCubit(sl(), sl()),
  );
  sl.registerFactory<NotificationSettingsCubit>(
    () => NotificationSettingsCubit(sl(), sl()),
  );
}
