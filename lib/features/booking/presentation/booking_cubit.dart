import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/booking_params.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/strategies/booking_slot_strategy.dart';
import '../domain/repositories/booking_waitlist_repository.dart';
import '../domain/usecases/join_booking_waitlist_usecase.dart';
import '../domain/services/operational_slot_clock.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository _bookingRepository;
  final BookingSlotStrategy _slotStrategy;
  final JoinBookingWaitlistUseCase _joinWaitlist;
  final BookingWaitlistRepository _waitlistRepository;
  bool _waitlistInFlight = false;
  int _availabilityRequestVersion = 0;
  int _slotPricesRequestVersion = 0;
  int _quoteRequestVersion = 0;
  final List<String> roomIds;
  final String loungeId;
  final String loungeOpeningTime;
  final String loungeClosingTime;

  String get roomId => roomIds.isNotEmpty ? roomIds.first : '';

  BookingCubit(
    this._bookingRepository,
    this._slotStrategy,
    BookingDetailsParams params, {
    required JoinBookingWaitlistUseCase joinWaitlist,
    required BookingWaitlistRepository waitlistRepository,
  }) : roomIds = params.rooms.map((r) => r.id).toList(),
       _joinWaitlist = joinWaitlist,
       _waitlistRepository = waitlistRepository,
       loungeId = params.lounge.id,
       loungeOpeningTime = params.lounge.openingTime,
       loungeClosingTime = params.lounge.closingTime,
       super(
         BookingState(
           selectedDate: params.selectedDate,
           playMode: params.playMode == 'multi'
               ? PlayMode.multi
               : PlayMode.single,
           extraControllersCount: params.extraControllers,
         ),
       ) {
    fetchBookedSlots(state.selectedDate);
    fetchRoomSlotsWithPrices(state.selectedDate);
  }

  Future<String> joinWaitlist(TimeOfDay slot) async {
    if (_waitlistInFlight || roomIds.length != 1) return 'waitlistUnavailable';
    _waitlistInFlight = true;
    try {
      final startAt = _resolveOperationalDateTime(state.selectedDate, slot);
      final result = await _joinWaitlist(
        roomId: roomId,
        startAt: startAt,
        endAt: startAt.add(const Duration(hours: 1)),
      );
      if (isClosed) return 'waitlistUnavailable';
      final messageKey = result.fold<String>(
        (failure) => switch (failure.message) {
          'SLOT_AVAILABLE_NOW' => 'waitlistAvailableNow',
          'ROOM_UNAVAILABLE' ||
          'OUTSIDE_WORKING_HOURS' => 'waitlistUnavailable',
          'WAITLIST_LIMIT' => 'waitlistLimit',
          _ => 'waitlistFailed',
        },
        (_) => 'waitlistJoined',
      );
      return messageKey;
    } finally {
      _waitlistInFlight = false;
    }
  }

  Future<(bool, String?)> activeWaitlistRequest(TimeOfDay slot) async {
    if (roomIds.length != 1) return (false, null);
    final startAt = _resolveOperationalDateTime(state.selectedDate, slot);
    final result = await _waitlistRepository.activeRequest(
      roomId: roomId,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
    );
    return result.fold((_) => (false, null), (id) => (true, id));
  }

  Future<String> cancelWaitlist(String requestId) async {
    final result = await _waitlistRepository.cancel(requestId);
    return result.fold(
      (_) => 'waitlistFailed',
      (cancelled) => cancelled ? 'waitlistCancelled' : 'waitlistUnavailable',
    );
  }

  Future<void> fetchRoomSlotsWithPrices(DateTime date) async {
    if (roomId.isEmpty) return;
    final requestVersion = ++_slotPricesRequestVersion;
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final result = await _bookingRepository.getRoomSlotsWithPrices(
      roomId: roomId,
      date: dateStr,
    );

    if (isClosed || requestVersion != _slotPricesRequestVersion) return;

    result.fold((_) => null, (slots) {
      // Rule #2: filter out unpriced slots (hourlyRate <= 0)
      final validSlots = slots.where((s) => s.isValidPriced).toList();
      emit(state.copyWith(slotPrices: validSlots));
    });
  }

  Future<void> fetchPriceQuote() async {
    final requestVersion = ++_quoteRequestVersion;
    final startTime = state.startTime;
    if (startTime == null || roomId.isEmpty) return;

    final startDateTime = _resolveOperationalDateTime(
      state.selectedDate,
      startTime,
    );
    final endDateTime = startDateTime.add(
      Duration(minutes: state.durationMinutes),
    );

    final dateStr =
        "${startDateTime.year}-${startDateTime.month.toString().padLeft(2, '0')}-${startDateTime.day.toString().padLeft(2, '0')}";
    final startStr =
        "${startDateTime.hour.toString().padLeft(2, '0')}:${startDateTime.minute.toString().padLeft(2, '0')}:00";
    final endStr =
        "${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00";

    final result = await _bookingRepository.quoteBookingPrice(
      roomId: roomId,
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      playMode: state.playMode == PlayMode.single ? 'single' : 'multi',
      extraControllers: state.extraControllersCount,
    );

    if (isClosed || requestVersion != _quoteRequestVersion) return;

    result.fold(
      (_) => null,
      (quote) => emit(state.copyWith(priceQuote: quote)),
    );
  }

  Future<void> fetchBookedSlots(DateTime date) async {
    final requestVersion = ++_availabilityRequestVersion;
    emit(state.copyWith(status: BookingStatus.loading, selectedDate: date));

    final Set<TimeOfDay> allBookedSlots = {};
    String? failureMsg;

    for (final rid in roomIds) {
      final result = await _bookingRepository.getRoomBookingsForDate(
        loungeId,
        date,
        roomId: rid,
      );
      if (isClosed || requestVersion != _availabilityRequestVersion) return;
      result.fold((failure) => failureMsg = failure.message, (rawBookings) {
        final slots = _slotStrategy.calculateBookedSlots(
          rawBookings: rawBookings,
          roomId: rid,
          date: date,
        );
        allBookedSlots.addAll(slots);
      });
    }

    if (failureMsg != null) {
      emit(
        state.copyWith(status: BookingStatus.error, errorMessage: failureMsg),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BookingStatus.success,
        selectedDate: date,
        bookedTimeSlots: allBookedSlots.toList(),
      ),
    );
  }

  /// Atomically acquires a server-side hold for the full requested range.
  Future<bool> verifyAvailabilityBeforeProceed() async {
    if (state.status == BookingStatus.loading) return false;
    final startTime = state.startTime;
    if (startTime == null) return false;

    emit(state.copyWith(status: BookingStatus.loading, clearHold: true));

    final startDateTime = _resolveOperationalDateTime(
      state.selectedDate,
      startTime,
    );
    final endDateTime = startDateTime.add(
      Duration(minutes: state.durationMinutes),
    );

    final result = await _bookingRepository.acquireBookingHold(
      roomIds: roomIds,
      startTime: startDateTime,
      endTime: endDateTime,
    );

    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: BookingStatus.error,
            errorMessage: failure.message,
            clearHold: true,
          ),
        );
        return false;
      },
      (data) {
        if (data['success'] != true) {
          emit(
            state.copyWith(
              status: BookingStatus.error,
              clearStartTime: true,
              clearHold: true,
              errorMessage:
                  data['error_code']?.toString() ?? 'bookingHoldFailed',
            ),
          );
          return false;
        }

        final holdToken = data['hold_token']?.toString();
        final holdExpiresAt = DateTime.tryParse(
          data['hold_expires_at']?.toString() ??
              data['expires_at']?.toString() ??
              '',
        );

        if (holdToken == null || holdToken.isEmpty || holdExpiresAt == null) {
          emit(
            state.copyWith(
              status: BookingStatus.error,
              clearHold: true,
              errorMessage: 'bookingHoldFailed',
            ),
          );
          return false;
        }

        emit(
          state.copyWith(
            status: BookingStatus.success,
            holdToken: holdToken,
            holdExpiresAt: holdExpiresAt,
            heldStartAt: startDateTime,
          ),
        );
        return true;
      },
    );
  }

  DateTime _resolveOperationalDateTime(DateTime selectedDate, TimeOfDay time) {
    return const OperationalSlotClock().resolve(
      businessDate: selectedDate,
      slot: time,
      opensAt: loungeOpeningTime,
      closesAt: loungeClosingTime,
    );
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) {
      return;
    }

    HapticFeedback.lightImpact();
    emit(
      state.copyWith(
        selectedDate: date,
        clearStartTime: true,
        clearHold: true,
        clearPriceQuote: true,
        slotPrices: const [],
        bookedTimeSlots: const [],
      ),
    );
    fetchBookedSlots(date);
    fetchRoomSlotsWithPrices(date);
    fetchPriceQuote();
  }

  /// Calculates maximum continuous free duration in minutes before the next booked slot
  int getMaxAvailableDurationMinutes([
    TimeOfDay? customStartTime,
    BookingState? customState,
  ]) {
    final sState = customState ?? state;
    final start = customStartTime ?? sState.startTime;
    if (start == null) return 720;

    final startDateTime = _resolveOperationalDateTime(
      sState.selectedDate,
      start,
    );

    int free15MinCount = 0;
    // Check up to 12 hours (48 slots of 15 minutes)
    for (int i = 0; i < 48; i++) {
      final checkTime = startDateTime.add(Duration(minutes: i * 15));
      final tod = TimeOfDay(hour: checkTime.hour, minute: checkTime.minute);
      if (sState.bookedTimeSlots.any(
        (slot) => slot.hour == tod.hour && slot.minute == tod.minute,
      )) {
        break; // Stop at the first booked slot!
      }
      free15MinCount++;
    }

    final maxMins = free15MinCount * 15;
    return maxMins < 15 ? 15 : maxMins;
  }

  void selectStartTime(TimeOfDay time) {
    if (isSlotBooked(time)) return;

    final now = DateTime.now();
    final isToday =
        state.selectedDate.year == now.year &&
        state.selectedDate.month == now.month &&
        state.selectedDate.day == now.day;

    if (isToday) {
      final slotDateTime = _resolveOperationalDateTime(
        state.selectedDate,
        time,
      );

      if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
        return;
      }
    }

    HapticFeedback.lightImpact();

    // Auto-cap duration if current duration extends past next booked slot!
    final tempState = state.copyWith(startTime: time);
    final maxAllowed = getMaxAvailableDurationMinutes(time, tempState);
    final cappedDuration = state.durationMinutes.clamp(15, maxAllowed);

    emit(tempState.copyWith(durationMinutes: cappedDuration));
    fetchPriceQuote();
  }

  void setDurationMinutes(int minutes) {
    final maxAllowed = getMaxAvailableDurationMinutes();
    final cappedMinutes = minutes.clamp(15, maxAllowed);
    HapticFeedback.lightImpact();
    emit(state.copyWith(durationMinutes: cappedMinutes));
    fetchPriceQuote();
  }

  void updateDuration(int deltaMinutes) {
    final maxAllowed = getMaxAvailableDurationMinutes();
    final newDuration = (state.durationMinutes + deltaMinutes).clamp(
      15,
      maxAllowed,
    );

    if (newDuration == state.durationMinutes && deltaMinutes > 0) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();
    emit(state.copyWith(durationMinutes: newDuration));
    fetchPriceQuote();
  }

  bool isSlotBooked(TimeOfDay time) {
    return state.bookedTimeSlots.any(
      (slot) => slot.hour == time.hour && slot.minute == time.minute,
    );
  }

  bool isRangeAvailable(TimeOfDay start, int durationMinutes) {
    final maxAllowed = getMaxAvailableDurationMinutes(start);
    return durationMinutes <= maxAllowed;
  }
}
