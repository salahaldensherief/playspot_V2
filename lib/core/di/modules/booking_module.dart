import 'package:get_it/get_it.dart';
import '../../../features/booking/data/data_source/remote/booking_remote_data_source.dart';
import '../../../features/booking/data/repos/booking_repo.dart';
import '../../../features/checkout/presentation/checkout_cubit.dart';

final sl = GetIt.instance;

void initBookingModule() {
  sl.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );

  sl.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(sl(), sl()),
  );
}
