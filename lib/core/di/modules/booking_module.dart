import 'package:get_it/get_it.dart';
import '../../../features/booking/data/datasources/remote/booking_remote_data_source.dart';
import '../../../features/booking/data/datasources/remote/booking_waitlist_remote_data_source.dart';
import '../../../features/booking/data/models/booking_params.dart';
import '../../../features/booking/data/repositories/booking_repository_impl.dart';
import '../../../features/booking/data/repositories/booking_waitlist_repository_impl.dart';
import '../../../features/booking/data/strategies/standard_booking_slot_strategy.dart';
import '../../../features/booking/domain/repositories/booking_repository.dart';
import '../../../features/booking/domain/repositories/booking_waitlist_repository.dart';
import '../../../features/booking/domain/usecases/get_lounge_price_range_usecase.dart';
import '../../../features/booking/domain/usecases/get_room_slots_with_prices_usecase.dart';
import '../../../features/booking/domain/usecases/join_booking_waitlist_usecase.dart';
import '../../../features/booking/domain/usecases/quote_booking_price_usecase.dart';
import '../../../features/booking/domain/strategies/booking_slot_strategy.dart';
import '../../../features/booking/presentation/booking_cubit.dart';
import '../../../features/checkout/presentation/checkout_cubit.dart';
import '../../../features/my_bookings/presentation/quick_rebook_cubit.dart';
import '../../../features/my_bookings/domain/usecases/build_quick_rebook_checkout_usecase.dart';
import '../../../features/my_bookings/domain/usecases/get_quick_rebook_slots_usecase.dart';
import '../../../features/my_bookings/domain/usecases/prepare_quick_rebook_usecase.dart';

import '../../../features/booking/domain/services/booking_availability_service.dart';

final sl = GetIt.instance;

void initBookingModule() {
  sl.registerLazySingleton<BookingAvailabilityService>(
    () => const BookingAvailabilityService(),
  );

  sl.registerLazySingleton<BookingSlotStrategy>(
    () => StandardBookingSlotStrategy(sl<BookingAvailabilityService>()),
  );

  sl.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<BookingWaitlistRemoteDataSource>(
    () => BookingWaitlistRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<BookingWaitlistRepository>(
    () => BookingWaitlistRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<JoinBookingWaitlistUseCase>(
    () => JoinBookingWaitlistUseCase(sl()),
  );

  sl.registerLazySingleton<QuoteBookingPriceUseCase>(
    () => QuoteBookingPriceUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton<GetRoomSlotsWithPricesUseCase>(
    () => GetRoomSlotsWithPricesUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton<GetLoungePriceRangeUseCase>(
    () => GetLoungePriceRangeUseCase(sl<BookingRepository>()),
  );

  sl.registerFactoryParam<BookingCubit, BookingDetailsParams, void>(
    (params, _) => BookingCubit(
      sl<BookingRepository>(),
      sl<BookingSlotStrategy>(),
      params,
      joinWaitlist: sl<JoinBookingWaitlistUseCase>(),
      waitlistRepository: sl<BookingWaitlistRepository>(),
    ),
  );

  sl.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(
      sl(),
      sl(),
      preferenceManager: sl(),
      storageService: sl(),
    ),
  );

  sl.registerLazySingleton<PrepareQuickRebookUseCase>(
    () => PrepareQuickRebookUseCase(sl(), sl()),
  );

  sl.registerLazySingleton<GetQuickRebookSlotsUseCase>(
    () => GetQuickRebookSlotsUseCase(sl(), sl()),
  );

  sl.registerLazySingleton<BuildQuickRebookCheckoutUseCase>(
    () => BuildQuickRebookCheckoutUseCase(sl()),
  );

  sl.registerFactory<QuickRebookCubit>(
    () => QuickRebookCubit(
      prepareQuickRebook: sl(),
      getQuickRebookSlots: sl(),
      buildQuickRebookCheckout: sl(),
    ),
  );
}
