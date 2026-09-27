import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/booking/domain/strategies/booking_slot_strategy.dart';
import 'package:playspot/features/home/domain/repositories/home_repository.dart';
import 'package:playspot/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import '../data/models/booking_model.dart';
import 'quick_rebook_state.dart';

class QuickRebookCubit extends Cubit<QuickRebookState> {
  final HomeRepository _homeRepository;
  final LoungeDetailsRemoteDataSource _loungeDetailsRemoteDataSource;
  final LoungeDetailsRepository _loungeDetailsRepository;
  final BookingRepository _bookingRepository;
  final BookingSlotStrategy _slotStrategy;

  QuickRebookCubit({
    required HomeRepository homeRepository,
    required LoungeDetailsRemoteDataSource loungeDetailsRemoteDataSource,
    required LoungeDetailsRepository loungeDetailsRepository,
    required BookingRepository bookingRepository,
    required BookingSlotStrategy slotStrategy,
  })  : _homeRepository = homeRepository,
        _loungeDetailsRemoteDataSource = loungeDetailsRemoteDataSource,
        _loungeDetailsRepository = loungeDetailsRepository,
        _bookingRepository = bookingRepository,
        _slotStrategy = slotStrategy,
        super(QuickRebookState(selectedDate: DateTime.now()));

  Future<void> initQuickRebook(BookingModel pastBooking) async {
    emit(state.copyWith(
      status: QuickRebookStatus.loading,
      pastBooking: pastBooking,
      selectedDate: DateTime.now(),
    ));

    try {
      final loungeId = pastBooking.loungeId;
      if (loungeId == null || loungeId.isEmpty) {
        emit(state.copyWith(
          status: QuickRebookStatus.error,
          errorMessage: 'Lounge identifier missing in booking record.',
        ));
        return;
      }

      // 1. Fetch real LoungeModel from Supabase
      final loungeResult = await _homeRepository.getLoungeById(loungeId);
      final lounge = loungeResult.fold(
        (failure) => null,
        (l) => l,
      );

      if (lounge == null) {
        emit(state.copyWith(
          status: QuickRebookStatus.error,
          errorMessage: 'Lounge is no longer active or available.',
        ));
        return;
      }

      // 2. Fetch real RoomModel from Supabase
      RoomModel? room;
      if (pastBooking.roomId != null && pastBooking.roomId!.isNotEmpty) {
        room = await _loungeDetailsRemoteDataSource.getRoomById(pastBooking.roomId!);
      }

      // Fallback: If roomId wasn't directly stored, find by loungeId & room name
      if (room == null) {
        final rooms = await _loungeDetailsRemoteDataSource.getRoomsByLoungeId(loungeId);
        if (rooms.isNotEmpty) {
          room = rooms.firstWhere(
            (r) => r.nameEn.toLowerCase() == pastBooking.roomName.toLowerCase() ||
                r.nameAr.toLowerCase() == pastBooking.roomName.toLowerCase(),
            orElse: () => rooms.first,
          );
        }
      }

      if (room == null || !room.isAvailable) {
        emit(state.copyWith(
          status: QuickRebookStatus.unavailable,
          pastBooking: pastBooking,
          lounge: lounge,
          errorMessage: 'This room is currently unavailable or unlisted.',
        ));
        return;
      }

      // 3. Fetch current available Extras from Supabase
      final extrasRes = await _loungeDetailsRepository.getExtras(loungeId);
      final List<ExtraModel> availableExtras = extrasRes.fold(
        (_) => <ExtraModel>[],
        (list) => list,
      );

      // Match previous canteen items against current Extras
      final Map<String, int> selectedAddonQuantities = {};
      final List<String> removedAddonNames = [];

      for (var prevItem in pastBooking.canteenItems) {
        final prevId = prevItem['id']?.toString() ?? prevItem['extra_id']?.toString() ?? '';
        final prevName = prevItem['name']?.toString() ?? '';
        final prevQty = (prevItem['quantity'] as num?)?.toInt() ?? 1;

        ExtraModel? matchedExtra;
        if (prevId.isNotEmpty) {
          final found = availableExtras.where((e) => e.id == prevId);
          if (found.isNotEmpty) matchedExtra = found.first;
        }

        if (matchedExtra == null && prevName.isNotEmpty) {
          final found = availableExtras.where(
            (e) => e.name.toLowerCase() == prevName.toLowerCase() ||
                e.nameAr.toLowerCase() == prevName.toLowerCase() ||
                e.nameEn.toLowerCase() == prevName.toLowerCase(),
          );
          if (found.isNotEmpty) matchedExtra = found.first;
        }

        if (matchedExtra != null) {
          selectedAddonQuantities[matchedExtra.id] = prevQty;
        } else if (prevName.isNotEmpty) {
          removedAddonNames.add(prevName);
        }
      }

      // 4. Determine duration in minutes (from past booking or default 60)
      int durationMins = 60;
      if (pastBooking.startTime.isNotEmpty && pastBooking.endTime.isNotEmpty) {
        try {
          final sParts = pastBooking.startTime.split(':');
          final eParts = pastBooking.endTime.split(':');
          if (sParts.length >= 2 && eParts.length >= 2) {
            final startMins = (int.parse(sParts[0]) * 60) + int.parse(sParts[1]);
            var endMins = (int.parse(eParts[0]) * 60) + int.parse(eParts[1]);
            if (endMins <= startMins) endMins += 1440;
            final diff = endMins - startMins;
            if (diff >= 15) durationMins = diff;
          }
        } catch (_) {}
      }

      // 5. Fetch booked slots and calculate available start slots for today
      final today = DateTime.now();
      final bookedSlots = await _fetchBookedSlots(loungeId, room.id, today);
      final availableSlots = _calculateAvailableSlots(today, bookedSlots, durationMins);

      final TimeOfDay? defaultSlot = availableSlots.isNotEmpty ? availableSlots.first : null;

      // 6. Recalculate current authoritative prices using current DB rates
      final prices = _recalculatePrices(
        room: room,
        durationMinutes: durationMins,
        playMode: pastBooking.playMode ?? 'single',
        availableExtras: availableExtras,
        selectedAddonQuantities: selectedAddonQuantities,
      );

      emit(state.copyWith(
        status: QuickRebookStatus.ready,
        pastBooking: pastBooking,
        lounge: lounge,
        room: room,
        availableExtras: availableExtras,
        selectedAddonQuantities: selectedAddonQuantities,
        removedAddonNames: removedAddonNames,
        selectedDate: today,
        availableSlots: availableSlots,
        selectedSlot: defaultSlot,
        durationMinutes: durationMins,
        roomSubtotal: prices['roomSubtotal']!,
        addonsTotal: prices['addonsTotal']!,
        totalPrice: prices['totalPrice']!,
      ));
    } catch (e, st) {
      AppLogger.error('QuickRebookCubit.initQuickRebook failed', e, st);
      emit(state.copyWith(
        status: QuickRebookStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> changeDate(DateTime date) async {
    if (state.room == null || state.lounge == null) return;
    emit(state.copyWith(status: QuickRebookStatus.loading, selectedDate: date));

    final bookedSlots = await _fetchBookedSlots(state.lounge!.id, state.room!.id, date);
    final availableSlots = _calculateAvailableSlots(date, bookedSlots, state.durationMinutes);
    final defaultSlot = availableSlots.isNotEmpty ? availableSlots.first : null;

    emit(state.copyWith(
      status: QuickRebookStatus.ready,
      selectedDate: date,
      availableSlots: availableSlots,
      selectedSlot: defaultSlot,
      clearSelectedSlot: defaultSlot == null,
    ));
  }

  void selectSlot(TimeOfDay slot) {
    emit(state.copyWith(selectedSlot: slot));
  }

  Future<void> updateDuration(int newDurationMinutes) async {
    if (state.room == null || state.lounge == null) return;

    final prices = _recalculatePrices(
      room: state.room!,
      durationMinutes: newDurationMinutes,
      playMode: state.pastBooking?.playMode ?? 'single',
      availableExtras: state.availableExtras,
      selectedAddonQuantities: state.selectedAddonQuantities,
    );

    final bookedSlots = await _fetchBookedSlots(state.lounge!.id, state.room!.id, state.selectedDate);
    final availableSlots = _calculateAvailableSlots(state.selectedDate, bookedSlots, newDurationMinutes);

    emit(state.copyWith(
      durationMinutes: newDurationMinutes,
      roomSubtotal: prices['roomSubtotal']!,
      addonsTotal: prices['addonsTotal']!,
      totalPrice: prices['totalPrice']!,
      availableSlots: availableSlots,
      selectedSlot: (state.selectedSlot != null && availableSlots.contains(state.selectedSlot))
          ? state.selectedSlot
          : (availableSlots.isNotEmpty ? availableSlots.first : null),
    ));
  }

  void updateAddonQuantity(String extraId, int newQuantity) {
    if (state.room == null) return;

    final updatedMap = Map<String, int>.from(state.selectedAddonQuantities);
    if (newQuantity > 0) {
      updatedMap[extraId] = newQuantity;
    } else {
      updatedMap.remove(extraId);
    }

    final prices = _recalculatePrices(
      room: state.room!,
      durationMinutes: state.durationMinutes,
      playMode: state.pastBooking?.playMode ?? 'single',
      availableExtras: state.availableExtras,
      selectedAddonQuantities: updatedMap,
    );

    emit(state.copyWith(
      selectedAddonQuantities: updatedMap,
      roomSubtotal: prices['roomSubtotal']!,
      addonsTotal: prices['addonsTotal']!,
      totalPrice: prices['totalPrice']!,
    ));
  }

  Future<Set<TimeOfDay>> _fetchBookedSlots(String loungeId, String roomId, DateTime date) async {
    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, date, roomId: roomId);
    final Set<TimeOfDay> booked = {};
    result.fold(
      (failure) => null,
      (rawBookings) {
        booked.addAll(_slotStrategy.calculateBookedSlots(
          rawBookings: rawBookings,
          roomId: roomId,
          date: date,
        ));
      },
    );
    return booked;
  }

  List<TimeOfDay> _calculateAvailableSlots(
    DateTime date,
    Set<TimeOfDay> bookedSlots,
    int durationMinutes,
  ) {
    final List<TimeOfDay> freeSlots = [];
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    // Check operating hours starting from 10:00 AM to 02:00 AM next day
    for (int h = 10; h < 26; h++) {
      final actualHour = h % 24;
      for (int m in const [0, 30]) {
        final slotTod = TimeOfDay(hour: actualHour, minute: m);

        if (isToday) {
          var slotDt = DateTime(now.year, now.month, now.day, actualHour, m);
          if (actualHour < 6) slotDt = slotDt.add(const Duration(days: 1));
          if (slotDt.isBefore(now.add(const Duration(minutes: 10)))) continue;
        }

        // Check if slot or range is free
        final isBooked = bookedSlots.any((b) => b.hour == actualHour && b.minute == m);
        if (!isBooked) {
          freeSlots.add(slotTod);
        }
      }
    }
    return freeSlots;
  }

  Map<String, double> _recalculatePrices({
    required RoomModel room,
    required int durationMinutes,
    required String playMode,
    required List<ExtraModel> availableExtras,
    required Map<String, int> selectedAddonQuantities,
  }) {
    final double hourlyRate = playMode == 'multi' ? room.hourlyRateMulti : room.hourlyRateSingle;
    final double durationHours = durationMinutes / 60.0;

    double roomSubtotal = hourlyRate * durationHours;
    if (room.hasActivePromo && room.promoDiscountValue > 0) {
      if (room.promoDiscountType == 'percentage') {
        roomSubtotal *= (1.0 - (room.promoDiscountValue / 100.0));
      } else {
        roomSubtotal = (roomSubtotal - room.promoDiscountValue).clamp(0.0, double.infinity);
      }
    }

    double addonsTotal = 0.0;
    selectedAddonQuantities.forEach((extraId, qty) {
      final extra = availableExtras.firstWhere(
        (e) => e.id == extraId,
        orElse: () => const ExtraModel(id: '', name: '', price: 0.0, category: 'other'),
      );
      if (extra.id.isNotEmpty && extra.price > 0) {
        addonsTotal += extra.price * qty;
      }
    });

    return {
      'roomSubtotal': roomSubtotal,
      'addonsTotal': addonsTotal,
      'totalPrice': roomSubtotal + addonsTotal,
    };
  }
}
