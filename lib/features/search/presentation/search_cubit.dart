import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cache/preference_manager.dart';
import '../../home/data/models/home_params.dart';
import '../../home/domain/usecases/discover_lounges_usecase.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final DiscoverLoungesUseCase _discoverLoungesUseCase;
  final PreferenceManager _preferenceManager;

  int _requestToken = 0;

  SearchCubit(
    this._discoverLoungesUseCase,
    this._preferenceManager,
  ) : super(const SearchState());

  Future<void> search({
    String query = '',
    bool isOpenOnly = false,
    String sortType = 'nearest',
  }) async {
    final requestToken = ++_requestToken;

    emit(
      state.copyWith(
        status: SearchStatus.loading,
        clearError: true,
      ),
    );

    final lat = double.tryParse(_preferenceManager.latitude());
    final lng = double.tryParse(_preferenceManager.longitude());

    final result = await _discoverLoungesUseCase(
      GetLoungesParams(
        lat: lat,
        lng: lng,
        searchQuery: query.trim().isEmpty ? null : query.trim(),
        sortType: sortType,
        isOpenOnly: isOpenOnly,
        limit: 100,
        offset: 0,
      ),
    );

    if (requestToken != _requestToken || isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (lounges) => emit(
        state.copyWith(
          status: SearchStatus.success,
          lounges: lounges,
          clearError: true,
        ),
      ),
    );
  }
}
