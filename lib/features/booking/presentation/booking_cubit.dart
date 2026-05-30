import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/data/repos/home_repos.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final HomeRepository _homeRepository;
  final String roomId;

  BookingCubit(this._homeRepository, this.roomId, DateTime? initialDate)
      : super(BookingState(selectedDate: initialDate ?? DateTime.now())) {
    fetchBookedSlots(state.selectedDate);
  }

  Future<void> fetchBookedSlots(DateTime date) async {
    emit(state.copyWith(status: BookingStatus.loading, selectedDate: date));
    try {
      final bookings = await _homeRepository.getBookingsForRoom(roomId, date);
      
      List<TimeOfDay> bookedSlots = [];
      for (var booking in bookings) {
        final start = DateTime.parse(booking['start_time']);
        final end = DateTime.parse(booking['end_time']);
        
        var current = start;
        while (current.isBefore(end)) {
          bookedSlots.add(TimeOfDay(hour: current.hour, minute: current.minute));
          current = current.add(const Duration(hours: 1));
        }
      }
      
      emit(state.copyWith(status: BookingStatus.success, bookedTimeSlots: bookedSlots));
    } catch (e) {
      emit(state.copyWith(status: BookingStatus.error));
    }
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) return;
    
    fetchBookedSlots(date);
  }

  void selectStartTime(TimeOfDay time) {
    if (isSlotBooked(time)) return;
    
    // Check if the current duration is possible with this start time
    // If not, we might want to reduce the duration or show a warning
    emit(state.copyWith(startTime: time));
  }

  void updateDuration(int delta) {
    final newDuration = (state.durationHours + delta).clamp(1, 12);
    
    // Validating if the new duration is possible with the selected start time
    if (state.startTime != null) {
      if (!isRangeAvailable(state.startTime!, newDuration)) {
        // You could emit a specific error state here if you want to show a SnackBar
        return;
      }
    }
    
    emit(state.copyWith(durationHours: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    // Only check the exact hour
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour);
  }

  bool isRangeAvailable(TimeOfDay start, int duration) {
    for (int i = 0; i < duration; i++) {
      final hourToCheck = (start.hour + i) % 24;
      if (state.bookedTimeSlots.any((slot) => slot.hour == hourToCheck)) {
        return false;
      }
    }
    return true;
  }

  bool isSlotAvailable(TimeOfDay slotStart) {
    return !isSlotBooked(slotStart);
  }

  Future<void> confirmBooking(String loungeId, double pricePerHour) async {
    if (state.startTime == null) return;

    emit(state.copyWith(status: BookingStatus.loading));

    try {
      final start = DateTime(
        state.selectedDate.year,
        state.selectedDate.month,
        state.selectedDate.day,
        state.startTime!.hour,
        state.startTime!.minute,
      );

      final end = start.add(Duration(hours: state.durationHours));
      final total = pricePerHour * state.durationHours;

      await _homeRepository.createBooking(
        roomId: roomId,
        loungeId: loungeId,
        startTime: start,
        endTime: end,
        totalPrice: total,
      );

      emit(state.copyWith(status: BookingStatus.success));
      // Refresh slots after booking
      fetchBookedSlots(state.selectedDate);
    } catch (e) {
      print("BOOKING ERROR: $e");
      emit(state.copyWith(status: BookingStatus.error));
    }
  }
}
