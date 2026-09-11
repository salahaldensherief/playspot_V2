import 'package:get_it/get_it.dart';
import '../../../features/booking/data/datasources/remote/booking_remote_data_source.dart';
import '../../../features/booking/domain/repositories/booking_repository.dart';
import '../../../features/booking/data/repositories/booking_repository_impl.dart';
import '../../../features/booking/data/models/booking_params.dart';
import '../../../features/booking/presentation/booking_cubit.dart';
import '../../../features/checkout/presentation/checkout_cubit.dart';

final sl = GetIt.instance;

void initBookingModule() {
  sl.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );

  sl.registerFactoryParam<BookingCubit, BookingDetailsParams, void>(
    (params, _) => BookingCubit(sl<BookingRepository>(), params),
  );

  sl.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(sl(), sl()),
  );
}
