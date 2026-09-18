import 'dart:developer';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/lounge_details_params.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/data/models/review_model.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/home/domain/repositories/home_repository.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/home/data/models/category_model.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'lounge_details_state.dart';

class LoungeDetailsCubit extends Cubit<LoungeDetailsState> {
  final LoungeDetailsRepository _loungeDetailsRepository;
  final HomeRepository _homeRepository;
  final BookingRepository _bookingRepository;
  final GetTournamentsUseCase _getTournamentsUseCase;

  LoungeDetailsCubit(
    this._loungeDetailsRepository,
    this._homeRepository,
    this._bookingRepository,
    this._getTournamentsUseCase,
  ) : super(const LoungeDetailsState());

  @override
  void emit(LoungeDetailsState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void init(LoungeModel lounge) {
    emit(state.copyWith(lounge: lounge));
    getLoungeDetails(lounge.id);
  }

  Future<void> initById(String loungeId) async {
    emit(state.copyWith(status: LoungeDetailsStatus.loading));
    final result = await _homeRepository.getLoungeById(loungeId);
    result.fold(
      (failure) => emit(state.copyWith(status: LoungeDetailsStatus.error)),
      (lounge) {
        if (lounge != null) {
          init(lounge);
        } else {
          emit(state.copyWith(status: LoungeDetailsStatus.error));
        }
      },
    );
  }

  Future<void> getLoungeDetails(String loungeId) async {
    if (loungeId.isEmpty) return;
    emit(state.copyWith(status: LoungeDetailsStatus.loading));

    try {
      log("FETCHING LOUNGE DETAILS IN PARALLEL...");
      final results = await Future.wait([
        _loungeDetailsRepository.getRoomsByLoungeId(loungeId, forceRefresh: false),
        _loungeDetailsRepository.getExtras(loungeId),
        _loungeDetailsRepository.getLoungeCategories(loungeId),
        _loungeDetailsRepository.getLoungeReviews(loungeId),
        _getTournamentsUseCase(loungeId: loungeId),
      ]);

      final roomsRes = results[0] as Either<Failure, List<RoomModel>>;
      final extrasRes = results[1] as Either<Failure, List<ExtraModel>>;
      final categoriesRes = results[2] as Either<Failure, List<CategoryModel>>;
      final reviewsRes = results[3] as Either<Failure, List<ReviewModel>>;
      final tournamentsRes = results[4] as Either<Failure, List<TournamentEntity>>;

      List<RoomModel>? rooms;
      List<ExtraModel>? extras;
      List<CategoryModel>? deviceCategories;
      List<ReviewModel>? reviews;
      List<TournamentEntity> tournaments = [];

      roomsRes.fold((l) { log("Rooms Fold Failure"); throw Exception("Rooms: ${l.message}"); }, (r) { rooms = r; });
      extrasRes.fold((l) { log("Extras Fold Failure"); throw Exception("Extras: ${l.message}"); }, (r) { extras = r; });
      categoriesRes.fold((l) { log("Categories Fold Failure"); throw Exception("Categories: ${l.message}"); }, (r) { deviceCategories = r; });
      reviewsRes.fold((l) { log("Reviews Fold Failure"); throw Exception("Reviews: ${l.message}"); }, (r) { reviews = r; });
      tournamentsRes.fold((l) { log("Tournaments Fold Failure"); tournaments = []; }, (t) { tournaments = t; });

      if (rooms == null || extras == null || deviceCategories == null || reviews == null) {
        throw Exception('Data loading failed');
      }

      final date = state.selectedDate ?? DateTime.now();
      
      final updateParams = UpdateBookingsParams(
          loungeId: loungeId,
          date: date,
          rooms: rooms!,
          extras: extras!,
          lounge: state.lounge!, 
          deviceCategories: deviceCategories!,
          reviews: reviews!,
        );
      
      await _updateBookings(updateParams, tournaments: tournaments);
      log("getLoungeDetails COMPLETED");
    } catch (e, stack) {
      log("CUBIT ERROR: $e", stackTrace: stack);
      emit(state.copyWith(status: LoungeDetailsStatus.error));
    }
  }

  /// Non-flickering date selection: Only sets `isDateLoading: true` without toggling global status to loading
  Future<void> selectDate(DateTime date) async {
    HapticFeedback.selectionClick();
    if (state.rooms.isEmpty || state.lounge == null) {
      emit(state.copyWith(selectedDate: date));
      return;
    }

    emit(state.copyWith(selectedDate: date, isDateLoading: true));

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
      emit(state.copyWith(isDateLoading: false));
    }
  }

  Future<void> _updateBookings(UpdateBookingsParams params, {List<TournamentEntity>? tournaments}) async {
    log("FETCHING BOOKINGS FOR DATE: ${params.date}");
    final bookingsResult = await _bookingRepository.getRoomBookingsForDate(params.loungeId, params.date);

    bookingsResult.fold(
      (failure) {
        log("CRITICAL BOOKINGS ERROR: ${failure.message}");
        emit(state.copyWith(
          isDateLoading: false,
          status: LoungeDetailsStatus.error,
        ));
      },
      (rawBookings) {
        log("BOOKINGS FETCHED SUCCESSFULLY: ${rawBookings.length} found");
        final Map<String, List<TimeRange>> bookedSlotsByRoom = {};
        final List<String> fullyBookedIds = [];
        final opHours = _calculateOperationalHours(params.lounge.opensAt, params.lounge.closesAt);

        for (final b in rawBookings) {
          final status = b['status']?.toString().toLowerCase().trim();
          if (status == 'cancelled' ||
              status == 'rejected' ||
              status == 'declined' ||
              status == 'canceled') {
            continue;
          }

          final roomId = b['room_id'].toString();
          final startAtRaw = b['start_at'] ?? b['start_time'];
          final endAtRaw = b['end_at'] ?? b['end_time'];
          final dateStr = b['date']?.toString();

          if (startAtRaw != null && endAtRaw != null) {
            final startStr = startAtRaw.toString().contains('-') ? startAtRaw.toString() : "$dateStr $startAtRaw";
            final endStr = endAtRaw.toString().contains('-') ? endAtRaw.toString() : "$dateStr $endAtRaw";

            try {
              final startAt = DateTime.parse(startStr.replaceFirst(' ', 'T'));
              var endAt = DateTime.parse(endStr.replaceFirst(' ', 'T'));
              
              if (endAt.isBefore(startAt) || endAt.isAtSameMomentAs(startAt)) {
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

        allActivities.sort((a, b) {
          if (a.toLowerCase().contains('ps')) return -1;
          if (b.toLowerCase().contains('ps')) return 1;
          return a.compareTo(b);
        });

        bool shouldClearRoom = state.selectedRoomId != null && fullyBookedIds.contains(state.selectedRoomId);

        emit(state.copyWith(
          status: LoungeDetailsStatus.success,
          isDateLoading: false,
          rooms: params.rooms,
          extras: params.extras,
          reviews: params.reviews ?? state.reviews,
          tournaments: tournaments ?? state.tournaments,
          bookedRoomIds: fullyBookedIds,
          bookedSlotsByRoom: bookedSlotsByRoom,
          categories: allActivities,
          deviceCategories: params.deviceCategories ?? state.deviceCategories,
          selectedDate: params.date,
          availableRoomsCount: params.rooms.length - fullyBookedIds.length,
          selectedCategory: state.selectedCategory,
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
    HapticFeedback.selectionClick();
    emit(state.selectedRoomId == roomId ? state.copyWith(clearRoom: true) : state.copyWith(selectedRoomId: roomId));
  }

  void setSpaceType(String spaceType) {
    if (state.selectedSpaceType == spaceType) return;
    HapticFeedback.selectionClick();
    emit(state.copyWith(selectedSpaceType: spaceType));
  }

  void setRoomPlayMode(String roomId, String mode) {
    HapticFeedback.selectionClick();
    final updated = Map<String, String>.from(state.roomPlayModes);
    updated[roomId] = mode;
    emit(state.copyWith(roomPlayModes: updated));
  }

  void updateRoomExtraControllers(String roomId, int delta) {
    HapticFeedback.selectionClick();
    final current = state.roomExtraControllers[roomId] ?? 0;
    final updated = Map<String, int>.from(state.roomExtraControllers);
    updated[roomId] = (current + delta).clamp(0, 4);
    emit(state.copyWith(roomExtraControllers: updated));
  }

  void setCategory(String categoryId) async {
    if (state.selectedCategory == categoryId) return;
    
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
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
