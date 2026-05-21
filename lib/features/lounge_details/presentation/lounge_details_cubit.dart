import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/repos/home_repos.dart';
import 'lounge_details_state.dart';

class LoungeDetailsCubit extends Cubit<LoungeDetailsState> {
  final HomeRepository _homeRepository;

  LoungeDetailsCubit(this._homeRepository) : super(const LoungeDetailsState());

  Future<void> getLoungeDetails(String loungeId) async {
    emit(state.copyWith(status: LoungeDetailsStatus.loading));

    try {
      final rooms = await _homeRepository.getRoomsByLoungeId(loungeId);
      final extras = await _homeRepository.getExtras();

      print("CUBIT: Fetched ${rooms.length} rooms and ${extras.length} extras for lounge $loungeId");

      emit(state.copyWith(
        status: LoungeDetailsStatus.success,
        rooms: rooms,
        extras: extras,
      ));
    } catch (e, stack) {
      print("CUBIT ERROR: $e");
      print(stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  void selectDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

  void toggleRoomSelection(String roomId) {
    if (state.selectedRoomId == roomId) {
      emit(state.copyWith(clearRoom: true));
    } else {
      emit(state.copyWith(selectedRoomId: roomId));
    }
  }

  void updateExtraQuantity(String extraId, int delta) {
    final currentQty = state.selectedExtras[extraId] ?? 0;
    final newQty = (currentQty + delta).clamp(0, 99);

    final updatedExtras = Map<String, int>.from(state.selectedExtras);
    if (newQty == 0) {
      updatedExtras.remove(extraId);
    } else {
      updatedExtras[extraId] = newQty;
    }

    emit(state.copyWith(selectedExtras: updatedExtras));
  }
}
