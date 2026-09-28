import 'package:get_it/get_it.dart';
import '../../../features/search/presentation/search_cubit.dart';
import '../../cache/preference_manager.dart';
import '../../../features/home/domain/usecases/discover_lounges_usecase.dart';

final sl = GetIt.instance;

void initSearchModule() {
  sl.registerFactory(
    () => SearchCubit(
      sl<DiscoverLoungesUseCase>(),
      sl<PreferenceManager>(),
    ),
  );
}
