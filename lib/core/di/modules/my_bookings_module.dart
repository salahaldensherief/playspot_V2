import 'package:get_it/get_it.dart';
import '../../../features/my_bookings/data/data_source/remote/my_bookings_remote_data_source.dart';
import '../../../features/my_bookings/data/repos/my_bookings_repo.dart';
import '../../../features/my_bookings/presentation/my_bookings_cubit.dart';

final sl = GetIt.instance;

void initMyBookingsModule() {
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
