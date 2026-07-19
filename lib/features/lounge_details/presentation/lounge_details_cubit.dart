import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/data/repos/lounge_details_repo.dart';
import 'package:playspot/features/home/data/repos/home_repos.dart';
import 'package:playspot/features/booking/data/repos/booking_repo.dart';
import 'lounge_details_state.dart';

class LoungeDetailsCubit extends Cubit<LoungeDetailsState> {
  final LoungeDetailsRepository _loungeDetailsRepository;
  final HomeRepository _homeRepository;
  final BookingRepository _bookingRepository;

  LoungeDetailsCubit(
    this._loungeDetailsRepository,
    this._homeRepository,
    this._bookingRepository,
  ) : super(const LoungeDetailsState());

  Future<void> getLoungeDetails(String loungeId) async {
    emit(state.copyWith(status: LoungeDetailsStatus.loading));

    try {
      final results = await Future.wait([
        _loungeDetailsRepository.getRoomsByLoungeId(loungeId),
        _loungeDetailsRepository.getExtras(),
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
      
      await _updateBookings(
        loungeId: loungeId,
        date: date,
        rooms: rooms!,
        extras: extras!,
        lounge: lounge!,
      );
    } catch (e, stack) {
      log("CUBIT ERROR: $e", stackTrace: stack);
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
      final loungesResult = await _homeRepository.getLounges();
      
      await loungesResult.fold(
        (failure) async => emit(state.copyWith(status: LoungeDetailsStatus.error)),
        (lounges) async {
          final lounge = lounges.firstWhere((l) => l.id == loungeId);
          await _updateBookings(
            loungeId: loungeId,
            date: date,
            rooms: state.rooms,
            extras: state.extras,
            lounge: lounge,
          );
        },
      );
    } catch (e) {
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  Future<void> _updateBookings({
    required String loungeId,
    required DateTime date,
    required List<RoomModel> rooms,
    required List<ExtraModel> extras,
    required LoungeModel lounge,
  }) async {
    final bookingsResult = await _bookingRepository.getRoomBookingsForDate(loungeId, date);

    bookingsResult.fold(
      (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
      (rawBookings) {
        final Map<String, List<TimeRange>> bookedSlotsByRoom = {};
        final List<String> fullyBookedIds = [];
        final opHours = _calculateOperationalHours(lounge.opensAt, lounge.closesAt);

        // Organize bookings by room
        for (final b in rawBookings) {
          final roomId = b['room_id'].toString();
          final startAt = DateTime.parse(b['start_at']);
          final endAt = DateTime.parse(b['end_at']);
          
          bookedSlotsByRoom.putIfAbsent(roomId, () => []).add(
            TimeRange(start: startAt, end: endAt),
          );
        }

        // Calculate fully booked rooms
        for (final room in rooms) {
          final slots = bookedSlotsByRoom[room.id] ?? [];
          double totalBookedHours = 0;
          for (final slot in slots) {
            totalBookedHours += slot.durationInHours;
          }

          if (totalBookedHours >= opHours) {
            fullyBookedIds.add(room.id);
          }
        }

        // استخراج التصنيفات الديناميكية من الغرف
        final allActivities = rooms.expand((r) => r.activityNames).toSet().toList();
        // ترتيب التصنيفات بحيث يظهر PS5 أولاً لو موجود
        allActivities.sort((a, b) {
          if (a.toLowerCase().contains('ps')) return -1;
          if (b.toLowerCase().contains('ps')) return 1;
          return a.compareTo(b);
        });

        final currentCategory = state.selectedCategory.isEmpty 
            ? (allActivities.isNotEmpty ? allActivities.first : '') 
            : state.selectedCategory;

        bool shouldClearRoom = state.selectedRoomId != null && fullyBookedIds.contains(state.selectedRoomId);

        emit(state.copyWith(
          status: LoungeDetailsStatus.success,
          rooms: rooms,
          extras: extras,
          bookedRoomIds: fullyBookedIds,
          bookedSlotsByRoom: bookedSlotsByRoom,
          categories: allActivities,
          selectedDate: date,
          availableRoomsCount: rooms.length - fullyBookedIds.length,
          selectedCategory: currentCategory,
          clearRoom: shouldClearRoom,
        ));
      },
    );
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
