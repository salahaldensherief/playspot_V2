import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/extra_model.dart';
import 'package:playspot/features/lounge_details/data/room_model.dart';
import '../../home/data/repos/home_repos.dart';
import 'lounge_details_state.dart';

class LoungeDetailsCubit extends Cubit<LoungeDetailsState> {
  final HomeRepository _homeRepository;

  LoungeDetailsCubit(this._homeRepository) : super(const LoungeDetailsState());

  Future<void> getLoungeDetails(String loungeId) async {
    emit(state.copyWith(status: LoungeDetailsStatus.loading));

    try {
      final results = await Future.wait([
        _homeRepository.getRoomsByLoungeId(loungeId),
        _homeRepository.getExtras(),
        _homeRepository.getLounges(),
      ]);

      List<RoomModel>? rooms;
      List<ExtraModel>? extras;
      LoungeModel? lounge;

      results[0].fold((l) => throw Exception(l.message), (r) => rooms = r as List<RoomModel>);
      results[1].fold((l) => throw Exception(l.message), (r) => extras = r as List<ExtraModel>);
      results[2].fold((l) => throw Exception(l.message), (r) {
        final lounges = r as List<LoungeModel>;
        lounge = lounges.firstWhere((l) => l.id == loungeId);
      });

      if (rooms == null || extras == null || lounge == null) {
        throw Exception('Data loading failed');
      }

      final date = state.selectedDate ?? DateTime.now();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final bookingsResult = await _homeRepository.getBookingsForLounge(loungeId, start, end);
      
      bookingsResult.fold(
        (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
        (bookings) {
          final opHours = _calculateOperationalHours(lounge!.opensAt, lounge!.closesAt);
          final List<String> fullyBookedIds = [];

          for (final room in rooms!) {
            double bookedDuration = 0;
            final roomBookings = bookings.where((b) => b['room_id'].toString() == room.id);

            for (final b in roomBookings) {
              final startTimeStr = b['start_time']?.toString();
              final endTimeStr = b['end_time']?.toString();

              if (startTimeStr != null && endTimeStr != null) {
                final startHour = int.parse(startTimeStr.split(':')[0]);
                final endHour = int.parse(endTimeStr.split(':')[0]);
                bookedDuration += (endHour - startHour).toDouble();
              }
            }
            if (bookedDuration >= opHours) {
              fullyBookedIds.add(room.id);
            }
          }

          emit(state.copyWith(
            status: LoungeDetailsStatus.success,
            rooms: rooms,
            extras: extras,
            bookedRoomIds: fullyBookedIds,
            selectedDate: date,
            availableRoomsCount: rooms!.length - fullyBookedIds.length,
          ));
        },
      );
    } catch (e, stack) {
      log("CUBIT ERROR: $e", stackTrace: stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  double _calculateOperationalHours(String opensAt, String closesAt) {
    if (!opensAt.contains(':') || !closesAt.contains(':')) return 16.0;

    try {
      final openParts = opensAt.split(':');
      final closeParts = closesAt.split(':');
      final openDuration = Duration(hours: int.parse(openParts[0]), minutes: int.parse(openParts[1]));
      var closeDuration = Duration(hours: int.parse(closeParts[0]), minutes: int.parse(closeParts[1]));
      
      if (closeDuration <= openDuration) closeDuration += const Duration(days: 1);
      
      return (closeDuration - openDuration).inMinutes / 60.0;
    } catch (e) {
      return 16.0;
    }
  }

  Future<void> selectDate(DateTime date) async {
    if (state.rooms.isEmpty) {
      emit(state.copyWith(selectedDate: date));
      return;
    }

    emit(state.copyWith(selectedDate: date, status: LoungeDetailsStatus.loading));

    final loungeId = state.rooms.first.loungeId;
    final loungesResult = await _homeRepository.getLounges();
    
    loungesResult.fold(
      (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
      (lounges) async {
        final lounge = lounges.firstWhere((l) => l.id == loungeId);
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));

        final bookingsResult = await _homeRepository.getBookingsForLounge(loungeId, start, end);
        
        bookingsResult.fold(
          (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
          (bookings) {
            final opHours = _calculateOperationalHours(lounge.opensAt, lounge.closesAt);
            List<String> fullyBookedIds = [];
            
            for (var room in state.rooms) {
              final roomBookings = bookings.where((b) => b['room_id'].toString() == room.id);
              double bookedDuration = 0;
              for (var b in roomBookings) {
                final startTimeStr = b['start_time']?.toString();
                final endTimeStr = b['end_time']?.toString();
                if (startTimeStr != null && endTimeStr != null) {
                  final startHour = int.parse(startTimeStr.split(':')[0]);
                  final endHour = int.parse(endTimeStr.split(':')[0]);
                  bookedDuration += (endHour - startHour).toDouble();
                }
              }
              if (bookedDuration >= opHours) fullyBookedIds.add(room.id);
            }

            bool shouldClearRoom = state.selectedRoomId != null && fullyBookedIds.contains(state.selectedRoomId);

            emit(state.copyWith(
              status: LoungeDetailsStatus.success,
              bookedRoomIds: fullyBookedIds,
              availableRoomsCount: state.rooms.length - fullyBookedIds.length,
              clearRoom: shouldClearRoom,
            ));
          },
        );
      },
    );
  }

  void toggleRoomSelection(String roomId) {
    emit(state.selectedRoomId == roomId ? state.copyWith(clearRoom: true) : state.copyWith(selectedRoomId: roomId));
  }

  void setCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void updateExtraQuantity(String extraId, int delta) {
    final currentQty = state.selectedExtras[extraId] ?? 0;
    final newQty = (currentQty + delta).clamp(0, 99);
    final updatedExtras = Map<String, int>.from(state.selectedExtras);
    
    if (newQty == 0) updatedExtras.remove(extraId);
    else updatedExtras[extraId] = newQty;

    emit(state.copyWith(selectedExtras: updatedExtras));
  }
}
