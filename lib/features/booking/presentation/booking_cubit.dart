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
    emit(state.copyWith(startTime: time));
  }

  void updateDuration(int delta) {
    final newDuration = (state.durationHours + delta).clamp(1, 12);
    emit(state.copyWith(durationHours: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour);
  }

  bool isSlotAvailable(TimeOfDay start) {
    // Check if the requested range (start to start + duration) overlaps with any booked slot
    for (int i = 0; i < state.durationHours; i++) {
      final hourToCheck = (start.hour + i) % 24;
      if (state.bookedTimeSlots.any((slot) => slot.hour == hourToCheck)) {
        return false;
      }
    }
    return true;
  }
}
