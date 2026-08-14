import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/data/models/home_params.dart';
import 'package:playspot/features/lounge_details/data/models/lounge_details_params.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/data/models/review_model.dart';
import 'package:playspot/features/lounge_details/data/repos/lounge_details_repo.dart';
import 'package:playspot/features/home/data/repos/home_repos.dart';
import 'package:playspot/features/booking/data/repos/booking_repo.dart';
import '../../home/data/models/category_model.dart';
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

  void init(LoungeModel lounge) {
    emit(state.copyWith(lounge: lounge));
    getLoungeDetails(lounge.id);
  }

  Future<void> getLoungeDetails(String loungeId) async {
    if (loungeId.isEmpty) return;
    emit(state.copyWith(status: LoungeDetailsStatus.loading));

    try {
      final results = await Future.wait([
        _loungeDetailsRepository.getRoomsByLoungeId(loungeId),
        _loungeDetailsRepository.getExtras(loungeId),
        _loungeDetailsRepository.getLoungeCategories(loungeId),
        _loungeDetailsRepository.getLoungeReviews(loungeId),
      ]);

      List<RoomModel>? rooms;
      List<ExtraModel>? extras;
      List<CategoryModel>? deviceCategories;
      List<ReviewModel>? reviews;

      results[0].fold((l) => throw Exception(l.message), (r) => rooms = r as List<RoomModel>);
      results[1].fold((l) => throw Exception(l.message), (r) => extras = r as List<ExtraModel>);
      results[2].fold((l) => throw Exception(l.message), (r) => deviceCategories = r as List<CategoryModel>);
      results[3].fold((l) => throw Exception(l.message), (r) => reviews = r as List<ReviewModel>);

      if (rooms == null || extras == null || deviceCategories == null || reviews == null) {
        throw Exception('Data loading failed');
      }

      final date = state.selectedDate ?? DateTime.now();
      
      await _updateBookings(
        UpdateBookingsParams(
          loungeId: loungeId,
          date: date,
          rooms: rooms!,
          extras: extras!,
          lounge: state.lounge!, 
          deviceCategories: deviceCategories!,
          reviews: reviews!,
        ),
      );
    } catch (e, stack) {
      log("CUBIT ERROR: $e", stackTrace: stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  Future<void> selectDate(DateTime date) async {
    if (state.rooms.isEmpty || state.lounge == null) {
      emit(state.copyWith(selectedDate: date));
      return;
    }

    emit(state.copyWith(selectedDate: date, status: LoungeDetailsStatus.loading));

    try {
      await _updateBookings(
        UpdateBookingsParams(
          loungeId: state.lounge!.id,
          date: date,
          rooms: state.rooms,
          extras: state.extras,
          lounge: state.lounge!,
          deviceCategories: state.deviceCategories,
          reviews: state.reviews,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  Future<void> _updateBookings(UpdateBookingsParams params) async {
    final bookingsResult = await _bookingRepository.getRoomBookingsForDate(params.loungeId, params.date);

    bookingsResult.fold(
      (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
      (rawBookings) {
        final Map<String, List<TimeRange>> bookedSlotsByRoom = {};
        final List<String> fullyBookedIds = [];
        final opHours = _calculateOperationalHours(params.lounge.opensAt, params.lounge.closesAt);

        // Organize bookings by room
        for (final b in rawBookings) {
          final roomId = b['room_id'].toString();
          final startAtRaw = b['start_at'] ?? b['start_time'];
          final endAtRaw = b['end_at'] ?? b['end_time'];
          final dateStr = b['date'];

          if (startAtRaw != null && endAtRaw != null) {
            final startStr = startAtRaw.toString().contains('-') ? startAtRaw.toString() : "${dateStr} $startAtRaw";
            final endStr = endAtRaw.toString().contains('-') ? endAtRaw.toString() : "${dateStr} $endAtRaw";

            try {
              final startAt = DateTime.parse(startStr.replaceFirst(' ', 'T'));
              var endAt = DateTime.parse(endStr.replaceFirst(' ', 'T'));
              
              if (endAt.isBefore(startAt)) {
                endAt = endAt.add(const Duration(days: 1));
              }
              
              bookedSlotsByRoom.putIfAbsent(roomId, () => []).add(
                TimeRange(start: startAt, end: endAt),
              );
            } catch (e) {
              log("ERROR parsing booking date: $e");
            }
          }
        }

        // Calculate fully booked rooms
        for (final room in params.rooms) {
          final slots = bookedSlotsByRoom[room.id] ?? [];
          double totalBookedHours = 0;
          for (final slot in slots) {
            totalBookedHours += slot.durationInHours;
          }

          if (totalBookedHours >= opHours) {
            fullyBookedIds.add(room.id);
          }
        }

        final allActivities = params.deviceCategories?.map((c) => c.nameEn).toList() ?? 
                             params.rooms.expand((r) => r.activityNames).toSet().toList();

        // ترتيب التصنيفات بحيث يظهر PS5 أولاً لو موجود
        allActivities.sort((a, b) {
          if (a.toLowerCase().contains('ps')) return -1;
          if (b.toLowerCase().contains('ps')) return 1;
          return a.compareTo(b);
        });

        bool shouldClearRoom = state.selectedRoomId != null && fullyBookedIds.contains(state.selectedRoomId);

        emit(state.copyWith(
          status: LoungeDetailsStatus.success,
          rooms: params.rooms,
          extras: params.extras,
          reviews: params.reviews ?? state.reviews,
          bookedRoomIds: fullyBookedIds,
          bookedSlotsByRoom: bookedSlotsByRoom,
          categories: allActivities,
          deviceCategories: params.deviceCategories ?? state.deviceCategories,
          selectedDate: params.date,
          availableRoomsCount: params.rooms.length - fullyBookedIds.length,
          selectedCategory: state.selectedCategory, // Keep current selection or empty
          clearRoom: shouldClearRoom,
          lounge: params.lounge,
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

  void setSpaceType(String spaceType) {
    if (state.selectedSpaceType == spaceType) return;
    emit(state.copyWith(selectedSpaceType: spaceType));
  }

  void setRoomPlayMode(String roomId, String mode) {
    final updated = Map<String, String>.from(state.roomPlayModes);
    updated[roomId] = mode;
    emit(state.copyWith(roomPlayModes: updated));
  }

  void updateRoomExtraControllers(String roomId, int delta) {
    final current = state.roomExtraControllers[roomId] ?? 0;
    final updated = Map<String, int>.from(state.roomExtraControllers);
    updated[roomId] = (current + delta).clamp(0, 4);
    emit(state.copyWith(roomExtraControllers: updated));
  }

  void setCategory(String categoryId) async {
    if (state.selectedCategory == categoryId) return;
    
    emit(state.copyWith(selectedCategory: categoryId, status: LoungeDetailsStatus.loading));

    final loungeId = state.lounge?.id ?? '';
    if (loungeId.isEmpty) return;

    final result = await _loungeDetailsRepository.getRoomsByLoungeId(
      loungeId, 
      categoryId: categoryId.toLowerCase() == 'all' ? null : categoryId
    );

    result.fold(
      (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
      (rooms) => emit(state.copyWith(
        status: LoungeDetailsStatus.success,
        rooms: rooms,
        selectedCategory: categoryId,
      )),
    );
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
