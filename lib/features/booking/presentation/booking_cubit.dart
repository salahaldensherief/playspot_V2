import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import '../data/models/booking_params.dart';
import '../domain/repositories/booking_repository.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository _bookingRepository;
  final String roomId;
  final String loungeId;

  BookingCubit(
    this._bookingRepository,
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

    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, date);

    result.fold(
      (failure) => emit(state.copyWith(
        status: BookingStatus.error,
        errorMessage: failure.message,
      )),
      (rawBookings) {
        final roomBookings = rawBookings
            .where((b) => b['room_id'].toString() == roomId)
            .map((b) => _parseBookingRow(b, date))
            .whereType<TimeRange>()
            .toList();

        List<TimeOfDay> bookedSlots = [];

        for (int h = 0; h < 24; h++) {
          for (int m in [0, 30]) {
            final slotDateTime = (h >= 10)
                ? DateTime(date.year, date.month, date.day, h, m)
                : DateTime(date.year, date.month, date.day + 1, h, m);
            final slotEnd = slotDateTime.add(const Duration(minutes: 30));

            final isOccupied = roomBookings.any((range) =>
                range.start.isBefore(slotEnd) && range.end.isAfter(slotDateTime));

            if (isOccupied) {
              bookedSlots.add(TimeOfDay(hour: h, minute: m));
            }
          }
        }

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

    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, state.selectedDate);

    return result.fold(
      (failure) {
        emit(state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ));
        return false;
      },
      (rawBookings) {
        final roomBookings = rawBookings
            .where((b) => b['room_id'].toString() == roomId)
            .map((b) => _parseBookingRow(b, state.selectedDate))
            .whereType<TimeRange>()
            .toList();

        List<TimeOfDay> bookedSlots = [];
        for (int h = 0; h < 24; h++) {
          for (int m in [0, 30]) {
            final slotDateTime = (h >= 10)
                ? DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, h, m)
                : DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day + 1, h, m);
            final slotEnd = slotDateTime.add(const Duration(minutes: 30));

            final isOccupied = roomBookings.any((range) =>
                range.start.isBefore(slotEnd) && range.end.isAfter(slotDateTime));

            if (isOccupied) {
              bookedSlots.add(TimeOfDay(hour: h, minute: m));
            }
          }
        }

        final start = state.startTime!;
        final startDateTime = (start.hour >= 10)
            ? DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, start.hour, start.minute)
            : DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day + 1, start.hour, start.minute);
        final endDateTime = startDateTime.add(Duration(minutes: state.durationMinutes));

        final isConflict = roomBookings.any((range) =>
            range.start.isBefore(endDateTime) && range.end.isAfter(startDateTime));

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

  TimeRange? _parseBookingRow(Map<String, dynamic> b, DateTime date) {
    final status = b['status']?.toString().toLowerCase().trim();
    if (status == 'cancelled' ||
        status == 'rejected' ||
        status == 'declined' ||
        status == 'canceled') {
      return null;
    }

    final startAt = b['start_at'] ?? b['start_time'];
    final endAt = b['end_at'] ?? b['end_time'];
    if (startAt == null || endAt == null) return null;

    final dateStr = b['date']?.toString() ??
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      final start = _parseDateTime(dateStr, startAt.toString());
      var end = _parseDateTime(dateStr, endAt.toString());
      if (start == null || end == null) return null;

      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        end = end.add(const Duration(days: 1));
      }

      return TimeRange(start: start, end: end);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateTime(String dateStr, String timeOrIsoStr) {
    if (timeOrIsoStr.contains('T') || (timeOrIsoStr.contains('-') && timeOrIsoStr.contains(' '))) {
      final parsed = DateTime.tryParse(timeOrIsoStr.replaceFirst(' ', 'T'));
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
      }
    }

    final dateParts = dateStr.split('-');
    if (dateParts.length < 3) return null;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    final timeParts = timeOrIsoStr.split(':');
    if (timeParts.length < 2) return null;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(year, month, day, hour, minute);
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) {
      return;
    }

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

    emit(state.copyWith(startTime: time));
  }

  void setDurationMinutes(int minutes) {
    if (state.startTime != null && !isRangeAvailable(state.startTime!, minutes)) return;
    emit(state.copyWith(durationMinutes: minutes));
  }

  void updateDuration(int deltaMinutes) {
    final newDuration = (state.durationMinutes + deltaMinutes).clamp(30, 720);
    if (state.startTime != null && !isRangeAvailable(state.startTime!, newDuration)) return;
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
