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
    
    final result = await _homeRepository.getBookingsForRoom(roomId, date);
    
    result.fold(
      (failure) => emit(state.copyWith(status: BookingStatus.error)),
      (bookings) {
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
      },
    );
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) return;
    
    fetchBookedSlots(date);
  }

  void selectStartTime(TimeOfDay time) {
    if (isSlotBooked(time)) return;
    emit(state.copyWith(startTime: time));
  }

  void updateDuration(int delta) {
    final newDuration = (state.durationHours + delta).clamp(1, 12);
    if (state.startTime != null && !isRangeAvailable(state.startTime!, newDuration)) return;
    emit(state.copyWith(durationHours: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour);
  }

  bool isRangeAvailable(TimeOfDay start, int duration) {
    for (int i = 0; i < duration; i++) {
      final hourToCheck = (start.hour + i) % 24;
      if (state.bookedTimeSlots.any((slot) => slot.hour == hourToCheck)) return false;
    }
    return true;
  }

  Future<void> confirmBooking(String loungeId, double pricePerHour) async {
    if (state.startTime == null) return;

    emit(state.copyWith(status: BookingStatus.loading));

    final start = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
      state.startTime!.hour,
      state.startTime!.minute,
    );

    final end = start.add(Duration(hours: state.durationHours));
    final total = pricePerHour * state.durationHours;

    final result = await _homeRepository.createBooking(
      roomId: roomId,
      loungeId: loungeId,
      startTime: start,
      endTime: end,
      totalPrice: total,
    );

    result.fold(
      (failure) => emit(state.copyWith(status: BookingStatus.error)),
      (_) {
        emit(state.copyWith(status: BookingStatus.success));
        fetchBookedSlots(state.selectedDate);
      },
    );
  }
}
