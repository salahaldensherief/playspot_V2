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
      final futures = await Future.wait([
        _homeRepository.getRoomsByLoungeId(loungeId),
        _homeRepository.getExtras(),
        _homeRepository.getLounges(),
      ]);

      final rooms = futures[0] as List<RoomModel>;
      final extras = futures[1] as List<ExtraModel>;
      final lounges = futures[2] as List<LoungeModel>;

      final lounge = lounges.firstWhere(
        (l) => l.id == loungeId,
        orElse: () => throw Exception('Lounge not found'),
      );

      final date = state.selectedDate ?? DateTime.now();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final bookings = await _homeRepository.getBookingsForLounge(
        loungeId,
        start,
        end,
      );

      final opHours = _calculateOperationalHours(
        lounge.opensAt,
        lounge.closesAt,
      );
      final List<String> fullyBookedIds = [];

      for (final room in rooms) {
        double bookedDuration = 0;
        final roomBookings = bookings.where(
          (b) => b['room_id'].toString() == room.id,
        );

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

      emit(
        state.copyWith(
          status: LoungeDetailsStatus.success,
          rooms: rooms,
          extras: extras,
          bookedRoomIds: fullyBookedIds,
          selectedDate: date,
          availableRoomsCount: rooms.length - fullyBookedIds.length,
        ),
      );
    } catch (e, stack) {
      log("CUBIT ERROR: $e", stackTrace: stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  double _calculateOperationalHours(String opensAt, String closesAt) {
    if (!opensAt.contains(':') || !closesAt.contains(':')) {
      return 16.0;
    }

    try {
      final openParts = opensAt.split(':');
      final closeParts = closesAt.split(':');

      final openDuration = Duration(
        hours: int.parse(openParts[0]),
        minutes: int.parse(openParts[1]),
      );

      var closeDuration = Duration(
        hours: int.parse(closeParts[0]),
        minutes: int.parse(closeParts[1]),
      );
      if (closeDuration <= openDuration) {
        closeDuration += const Duration(days: 1);
      }
      final totalDuration = closeDuration - openDuration;
      return totalDuration.inMinutes / 60.0;
    } catch (e) {
      return 16.0;
    }
  }

  Future<void> selectDate(DateTime date) async {
    if (state.rooms.isEmpty) {
      emit(state.copyWith(selectedDate: date));
      return;
    }

    emit(
      state.copyWith(selectedDate: date, status: LoungeDetailsStatus.loading),
    );

    try {
      final loungeId = state.rooms.first.loungeId;
      final lounges = await _homeRepository.getLounges();
      final lounge = lounges.firstWhere((l) => l.id == loungeId);

      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final bookings = await _homeRepository.getBookingsForLounge(
        loungeId,
        start,
        end,
      );
      final opHours = _calculateOperationalHours(
        lounge.opensAt,
        lounge.closesAt,
      );

      List<String> fullyBookedIds = [];
      for (var room in state.rooms) {
        final roomBookings = bookings.where(
          (b) => b['room_id'].toString() == room.id,
        );
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

        if (bookedDuration >= opHours) {
          fullyBookedIds.add(room.id);
        }
      }

      bool shouldClearRoom =
          state.selectedRoomId != null &&
          fullyBookedIds.contains(state.selectedRoomId);

      emit(
        state.copyWith(
          status: LoungeDetailsStatus.success,
          bookedRoomIds: fullyBookedIds,
          availableRoomsCount: state.rooms.length - fullyBookedIds.length,
          clearRoom: shouldClearRoom,
        ),
      );
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

  void setCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
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
