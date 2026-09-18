import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/constants/booking_status.dart';
import '../domain/repositories/my_bookings_repository.dart';
import 'my_bookings_state.dart';

class MyBookingsCubit extends Cubit<MyBookingsState> {
  final MyBookingsRepository _repository;
  DateTime? _lastFetchTime;
  bool _isFetching = false;

  MyBookingsCubit(this._repository) : super(const MyBookingsState());

  /// Refreshes bookings if data is stale (older than [staleDuration]) or if forced.
  /// Protects against spamming backend while ensuring fresh data on screen entry.
  Future<void> refreshBookingsIfStale({
    Duration staleDuration = const Duration(seconds: 10),
    bool force = false,
  }) async {
    final isStale = _lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > staleDuration;

    if (!force && !isStale && state.status == MyBookingsStatus.success) {
      return;
    }

    await getMyBookings(force: force);
  }

  Future<void> getMyBookings({bool force = true}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final hasExistingData = state.upcomingBookings.isNotEmpty ||
          state.pastBookings.isNotEmpty ||
          state.cancelledBookings.isNotEmpty;

      // Show full loading shimmer only if no existing bookings exist
      if (!hasExistingData) {
        emit(state.copyWith(status: MyBookingsStatus.loading));
      }

      final result = await _repository.getMyBookings();

      result.fold(
        (failure) => emit(state.copyWith(
          status: MyBookingsStatus.failure,
          errorMessage: failure.message,
        )),
        (bookings) {
          _lastFetchTime = DateTime.now();
          final upcoming = bookings.where((b) => b.isUpcoming).toList();
          final past = bookings
              .where((b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.inProgress)
              .toList();
          final cancelled = bookings
              .where((b) => b.status == BookingStatus.cancelled)
              .toList();

          emit(state.copyWith(
            status: MyBookingsStatus.success,
            upcomingBookings: upcoming,
            pastBookings: past,
            cancelledBookings: cancelled,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: MyBookingsStatus.failure,
        errorMessage: e.toString(),
      ));
    } finally {
      _isFetching = false;
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    emit(state.copyWith(cancellingBookingId: bookingId));
    final result = await _repository.cancelBooking(bookingId);
    result.fold(
      (failure) => emit(state.copyWith(
        clearCancelling: true,
        status: MyBookingsStatus.failure,
        errorMessage: failure.message,
      )),
      (_) {
        emit(state.copyWith(
          clearCancelling: true,
          status: MyBookingsStatus.success,
        ));
        getMyBookings(force: true);
      },
    );
  }
}
