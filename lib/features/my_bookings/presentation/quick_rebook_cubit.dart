import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/booking_slot_utils.dart';
import '../../booking/data/models/booking_params.dart';
import '../data/models/booking_model.dart';
import '../domain/entities/quick_rebook_setup.dart';
import '../domain/quick_rebook_preference.dart';
import '../domain/usecases/build_quick_rebook_checkout_usecase.dart';
import '../domain/usecases/get_quick_rebook_slots_usecase.dart';
import '../domain/usecases/prepare_quick_rebook_usecase.dart';
import 'quick_rebook_state.dart';

class QuickRebookCubit extends Cubit<QuickRebookState> {
  final PrepareQuickRebookUseCase _prepareQuickRebook;
  final GetQuickRebookSlotsUseCase _getQuickRebookSlots;
  final BuildQuickRebookCheckoutUseCase _buildQuickRebookCheckout;

  QuickRebookSetup? _setup;
  int _slotRequest = 0;

  QuickRebookCubit({
    required PrepareQuickRebookUseCase prepareQuickRebook,
    required GetQuickRebookSlotsUseCase getQuickRebookSlots,
    required BuildQuickRebookCheckoutUseCase buildQuickRebookCheckout,
  })  : _prepareQuickRebook = prepareQuickRebook,
        _getQuickRebookSlots = getQuickRebookSlots,
        _buildQuickRebookCheckout = buildQuickRebookCheckout,
        super(QuickRebookState(selectedDate: DateTime.now()));

  Future<void> initQuickRebook(BookingModel pastBooking) async {
    final suggestedDate = QuickRebookPreference.nextVisitDate(
      pastBooking.date,
      DateTime.now(),
    );
    final request = ++_slotRequest;

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        pastBooking: pastBooking,
        selectedDate: suggestedDate,
      ),
    );

    final setupResult = await _prepareQuickRebook(pastBooking);
    if (isClosed || request != _slotRequest) return;

    await setupResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: QuickRebookStatus.unavailable,
            errorMessage: failure.message,
          ),
        );
      },
      (setup) async {
        _setup = setup;
        final targetTime = BookingSlotUtils.resolveTargetTime(
          setup.pastBooking.startTime,
          setup.pastBooking.startDateTime,
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // 1. Try today's slots first
        final todaySlots = await _fetchSlotsForDate(
          setup,
          today,
          setup.durationMinutes,
        );
        if (isClosed || request != _slotRequest) return;

        DateTime activeDate = today;
        List<TimeOfDay> activeSlots = todaySlots;
        final suggestedDates = <DateTime>[];

        if (todaySlots.isNotEmpty) {
          suggestedDates.add(today);
        } else {
          // Smart Rebook: Scan next 7-14 days to find available slots
          final candidateDates = BookingSlotUtils.buildCandidateDates(
            today,
            setup.pastBooking.date.weekday,
          );

          for (final candidate in candidateDates) {
            if (isClosed || request != _slotRequest) return;
            final slots = await _fetchSlotsForDate(
              setup,
              candidate,
              setup.durationMinutes,
            );
            if (slots.isNotEmpty) {
              suggestedDates.add(candidate);
              if (activeSlots.isEmpty) {
                activeDate = candidate;
                activeSlots = slots;
              }
              if (suggestedDates.length >= 4) break;
            }
          }
        }

        if (isClosed || request != _slotRequest) return;

        final selectedSlot = activeSlots.isEmpty
            ? null
            : BookingSlotUtils.findClosestSlot(activeSlots, targetTime);

        emit(
          state.copyWith(
            status: QuickRebookStatus.ready,
            pastBooking: setup.pastBooking,
            lounge: setup.lounge,
            room: setup.room,
            availableExtras: setup.availableExtras,
            selectedAddonQuantities: setup.selectedAddonQuantities,
            removedAddonNames: setup.removedAddonNames,
            selectedDate: activeDate,
            availableSlots: activeSlots,
            selectedSlot: selectedSlot,
            clearSelectedSlot: selectedSlot == null,
            suggestedDates: suggestedDates,
            durationMinutes: setup.durationMinutes,
          ),
        );
      },
    );
  }

  Future<void> changeDate(DateTime date) async {
    final setup = _setup;
    if (setup == null) return;
    final request = ++_slotRequest;

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        selectedDate: date,
      ),
    );

    final slots = await _fetchSlotsForDate(setup, date, state.durationMinutes);
    if (isClosed || request != _slotRequest) return;

    final targetTime = BookingSlotUtils.resolveTargetTime(
      setup.pastBooking.startTime,
      setup.pastBooking.startDateTime,
    );
    final selectedSlot = slots.isEmpty
        ? null
        : BookingSlotUtils.findClosestSlot(slots, targetTime);

    emit(
      state.copyWith(
        status: QuickRebookStatus.ready,
        selectedDate: date,
        availableSlots: slots,
        selectedSlot: selectedSlot,
        clearSelectedSlot: selectedSlot == null,
      ),
    );
  }

  void selectSlot(TimeOfDay slot) {
    if (!state.availableSlots.contains(slot)) return;
    emit(state.copyWith(selectedSlot: slot));
  }

  Future<void> updateDuration(int newDurationMinutes) async {
    final setup = _setup;
    if (setup == null) return;
    final request = ++_slotRequest;

    final normalizedDuration =
        newDurationMinutes.clamp(15, 24 * 60).toInt();

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        durationMinutes: normalizedDuration,
      ),
    );

    final slots = await _fetchSlotsForDate(
      setup,
      state.selectedDate,
      normalizedDuration,
    );
    if (isClosed || request != _slotRequest) return;

    final targetTime = BookingSlotUtils.resolveTargetTime(
      setup.pastBooking.startTime,
      setup.pastBooking.startDateTime,
    );
    final selectedSlot = state.selectedSlot != null && slots.contains(state.selectedSlot)
        ? state.selectedSlot
        : (slots.isEmpty ? null : BookingSlotUtils.findClosestSlot(slots, targetTime));

    emit(
      state.copyWith(
        status: QuickRebookStatus.ready,
        durationMinutes: normalizedDuration,
        availableSlots: slots,
        selectedSlot: selectedSlot,
        clearSelectedSlot: selectedSlot == null,
      ),
    );
  }

  Future<List<TimeOfDay>> _fetchSlotsForDate(
    QuickRebookSetup setup,
    DateTime date,
    int durationMinutes,
  ) async {
    final slotsResult = await _getQuickRebookSlots(
      loungeId: setup.lounge.id,
      roomId: setup.room.id,
      date: date,
      openingTime: setup.lounge.openingTime,
      closingTime: setup.lounge.closingTime,
      durationMinutes: durationMinutes,
    );

    return slotsResult.fold(
      (_) => const <TimeOfDay>[],
      (slots) => slots,
    );
  }

  void updateAddonQuantity(String extraId, int newQuantity) {
    final setup = _setup;
    if (setup == null) return;

    final isAvailable = setup.availableExtras.any(
      (extra) => extra.id == extraId,
    );
    if (!isAvailable) return;

    final updated = Map<String, int>.from(
      state.selectedAddonQuantities,
    );

    if (newQuantity <= 0) {
      updated.remove(extraId);
    } else {
      updated[extraId] = newQuantity.clamp(1, 100).toInt();
    }

    emit(
      state.copyWith(
        selectedAddonQuantities: updated,
      ),
    );
  }

  Future<CheckoutParams?> prepareCheckout() async {
    final setup = _setup;
    final selectedSlot = state.selectedSlot;

    if (setup == null || selectedSlot == null) {
      return null;
    }

    emit(state.copyWith(status: QuickRebookStatus.loading));

    final result = await _buildQuickRebookCheckout(
      setup: setup,
      selectedDate: state.selectedDate,
      selectedSlot: selectedSlot,
      durationMinutes: state.durationMinutes,
      selectedAddonQuantities: state.selectedAddonQuantities,
    );

    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: QuickRebookStatus.error,
            errorMessage: failure.message,
          ),
        );
        return null;
      },
      (checkoutParams) {
        emit(state.copyWith(status: QuickRebookStatus.ready));
        return checkoutParams;
      },
    );
  }
}
