import 'package:get_it/get_it.dart';
import '../../../features/profile/data/data_source/remote/profile_remote_data_source.dart';
import '../../../features/profile/data/repos/profile_repo.dart';
import '../../../features/profile/presentation/edit_profile/edit_profile_cubit.dart';
import '../../../features/profile/presentation/profile_cubit.dart';

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
}
