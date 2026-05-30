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
      final date = state.selectedDate ?? DateTime.now();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      
      final bookedRoomIds = await _homeRepository.getBookedRoomIds(loungeId, start, end);

      print("CUBIT: Fetched ${rooms.length} rooms, ${extras.length} extras, and ${bookedRoomIds.length} booked rooms for lounge $loungeId");

      emit(state.copyWith(
        status: LoungeDetailsStatus.success,
        rooms: rooms,
        extras: extras,
        bookedRoomIds: bookedRoomIds,
        selectedDate: date,
        availableRoomsCount: rooms.length - bookedRoomIds.length,
      ));
    } catch (e, stack) {
      print("CUBIT ERROR: $e");
      print(stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  Future<void> selectDate(DateTime date) async {
    if (state.rooms.isEmpty) {
      emit(state.copyWith(selectedDate: date));
      return;
    }

    emit(state.copyWith(selectedDate: date, status: LoungeDetailsStatus.loading));
    
    try {
      final loungeId = state.rooms.first.loungeId;
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      
      final bookedRoomIds = await _homeRepository.getBookedRoomIds(loungeId, start, end);
      
      // If the currently selected room is now booked on the new date, clear the selection
      bool shouldClearRoom = state.selectedRoomId != null && bookedRoomIds.contains(state.selectedRoomId);

      emit(state.copyWith(
        status: LoungeDetailsStatus.success,
        bookedRoomIds: bookedRoomIds,
        availableRoomsCount: state.rooms.length - bookedRoomIds.length,
        clearRoom: shouldClearRoom,
      ));
    } catch (e) {
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
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
