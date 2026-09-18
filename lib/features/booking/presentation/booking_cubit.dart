import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/booking_params.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/strategies/booking_slot_strategy.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository _bookingRepository;
  final BookingSlotStrategy _slotStrategy;
  final String roomId;
  final String loungeId;

  BookingCubit(
    this._bookingRepository,
    this._slotStrategy,
    BookingDetailsParams params,
  )   : roomId = params.room.id,
        loungeId = params.lounge.id,
        super(BookingState(
          selectedDate: params.selectedDate,
          playMode: params.playMode == 'multi' ? PlayMode.multi : PlayMode.single,
          extraControllersCount: params.extraControllers,
        )) {
    fetchBookedSlots(state.selectedDate);
  }

  Future<void> fetchBookedSlots(DateTime date) async {
    emit(state.copyWith(status: BookingStatus.loading, selectedDate: date));

    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, date, roomId: roomId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: BookingStatus.error,
        errorMessage: failure.message,
      )),
      (rawBookings) {
        final bookedSlots = _slotStrategy.calculateBookedSlots(
          rawBookings: rawBookings,
          roomId: roomId,
          date: date,
        );

        emit(state.copyWith(
          status: BookingStatus.success,
          selectedDate: date,
          bookedTimeSlots: bookedSlots,
        ));
      },
    );
  }

  /// Re-verifies slot availability against Supabase right before proceeding to checkout.
  /// Handles race conditions where another user booked the slot.
  Future<bool> verifyAvailabilityBeforeProceed() async {
    if (state.startTime == null) return false;

    emit(state.copyWith(status: BookingStatus.loading));

    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, state.selectedDate, roomId: roomId);

    return result.fold(
      (failure) {
        emit(state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ));
        return false;
      },
      (rawBookings) {
        final bookedSlots = _slotStrategy.calculateBookedSlots(
          rawBookings: rawBookings,
          roomId: roomId,
          date: state.selectedDate,
        );

        final isConflict = _slotStrategy.isBookingConflicting(
          rawBookings: rawBookings,
          roomId: roomId,
          date: state.selectedDate,
          startTime: state.startTime!,
          durationMinutes: state.durationMinutes,
        );

        if (isConflict) {
          emit(state.copyWith(
            status: BookingStatus.error,
            bookedTimeSlots: bookedSlots,
            clearStartTime: true,
            errorMessage: "overlappingBookingError",
          ));
          return false;
        }

        emit(state.copyWith(
          status: BookingStatus.success,
          bookedTimeSlots: bookedSlots,
        ));
        return true;
      },
    );
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) {
      return;
    }

    HapticFeedback.lightImpact();
    fetchBookedSlots(date);
  }

  void selectStartTime(TimeOfDay time) {
    if (isSlotBooked(time)) return;

    final now = DateTime.now();
    final isToday = state.selectedDate.year == now.year &&
        state.selectedDate.month == now.month &&
        state.selectedDate.day == now.day;

    if (isToday) {
      var slotDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (time.hour < 10) {
        slotDateTime = slotDateTime.add(const Duration(days: 1));
      }

      if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
        return;
      }
    }

    HapticFeedback.lightImpact();
    emit(state.copyWith(startTime: time));
  }

  void setDurationMinutes(int minutes) {
    if (state.startTime != null && !isRangeAvailable(state.startTime!, minutes)) return;
    HapticFeedback.lightImpact();
    emit(state.copyWith(durationMinutes: minutes));
  }

  void updateDuration(int deltaMinutes) {
    final newDuration = (state.durationMinutes + deltaMinutes).clamp(30, 720);
    if (state.startTime != null && !isRangeAvailable(state.startTime!, newDuration)) return;
    HapticFeedback.lightImpact();
    emit(state.copyWith(durationMinutes: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour && slot.minute == time.minute);
  }

  bool isRangeAvailable(TimeOfDay start, int durationMinutes) {
    final startDateTime = (start.hour >= 10)
        ? DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, start.hour, start.minute)
        : DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day + 1, start.hour, start.minute);

    for (int i = 0; i < durationMinutes; i += 30) {
      final checkTime = startDateTime.add(Duration(minutes: i));
      final tod = TimeOfDay(hour: checkTime.hour, minute: checkTime.minute);
      if (state.bookedTimeSlots.any((slot) => slot.hour == tod.hour && slot.minute == tod.minute)) {
        return false;
      }
    }
    return true;
  }
}
