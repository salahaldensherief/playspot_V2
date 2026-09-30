import 'package:get_it/get_it.dart';
import '../../../features/slot_waitlist/data/datasources/remote/slot_waitlist_remote_data_source.dart';
import '../../../features/slot_waitlist/data/repositories/slot_waitlist_repository_impl.dart';
import '../../../features/slot_waitlist/domain/repositories/slot_waitlist_repository.dart';
import '../../../features/slot_waitlist/domain/usecases/join_slot_waitlist_usecase.dart';

final sl = GetIt.instance;

void initSlotWaitlistModule() {
  sl.registerLazySingleton<SlotWaitlistRemoteDataSource>(
    () => SlotWaitlistRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<SlotWaitlistRepository>(
    () => SlotWaitlistRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<JoinSlotWaitlistUseCase>(
    () => JoinSlotWaitlistUseCase(sl()),
  );
}
