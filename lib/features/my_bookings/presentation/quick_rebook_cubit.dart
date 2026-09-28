import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../booking/data/models/booking_params.dart';
import '../data/models/booking_model.dart';
import '../domain/entities/quick_rebook_setup.dart';
import '../domain/usecases/build_quick_rebook_checkout_usecase.dart';
import '../domain/usecases/get_quick_rebook_slots_usecase.dart';
import '../domain/usecases/prepare_quick_rebook_usecase.dart';
import 'quick_rebook_state.dart';

class QuickRebookCubit extends Cubit<QuickRebookState> {
  final PrepareQuickRebookUseCase _prepareQuickRebook;
  final GetQuickRebookSlotsUseCase _getQuickRebookSlots;
  final BuildQuickRebookCheckoutUseCase _buildQuickRebookCheckout;

  QuickRebookSetup? _setup;

  QuickRebookCubit({
    required PrepareQuickRebookUseCase prepareQuickRebook,
    required GetQuickRebookSlotsUseCase getQuickRebookSlots,
    required BuildQuickRebookCheckoutUseCase buildQuickRebookCheckout,
  })  : _prepareQuickRebook = prepareQuickRebook,
        _getQuickRebookSlots = getQuickRebookSlots,
        _buildQuickRebookCheckout = buildQuickRebookCheckout,
        super(QuickRebookState(selectedDate: DateTime.now()));

  Future<void> initQuickRebook(BookingModel pastBooking) async {
    final today = DateTime.now();

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        pastBooking: pastBooking,
        selectedDate: today,
      ),
    );

    final setupResult = await _prepareQuickRebook(pastBooking);
    if (isClosed) return;

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

        final slotsResult = await _getQuickRebookSlots(
          loungeId: setup.lounge.id,
          roomId: setup.room.id,
          date: today,
          openingTime: setup.lounge.openingTime,
          closingTime: setup.lounge.closingTime,
          durationMinutes: setup.durationMinutes,
        );

        if (isClosed) return;

        slotsResult.fold(
          (failure) {
            emit(
              state.copyWith(
                status: QuickRebookStatus.error,
                errorMessage: failure.message,
              ),
            );
          },
          (slots) {
            emit(
              state.copyWith(
                status: QuickRebookStatus.ready,
                pastBooking: setup.pastBooking,
                lounge: setup.lounge,
                room: setup.room,
                availableExtras: setup.availableExtras,
                selectedAddonQuantities:
                    setup.selectedAddonQuantities,
                removedAddonNames: setup.removedAddonNames,
                selectedDate: today,
                availableSlots: slots,
                selectedSlot: slots.isEmpty ? null : slots.first,
                clearSelectedSlot: slots.isEmpty,
                durationMinutes: setup.durationMinutes,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> changeDate(DateTime date) async {
    final setup = _setup;
    if (setup == null) return;

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        selectedDate: date,
      ),
    );

    final slotsResult = await _getQuickRebookSlots(
      loungeId: setup.lounge.id,
      roomId: setup.room.id,
      date: date,
      openingTime: setup.lounge.openingTime,
      closingTime: setup.lounge.closingTime,
      durationMinutes: state.durationMinutes,
    );

    if (isClosed) return;

    slotsResult.fold(
      (failure) {
        emit(
          state.copyWith(
            status: QuickRebookStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (slots) {
        emit(
          state.copyWith(
            status: QuickRebookStatus.ready,
            selectedDate: date,
            availableSlots: slots,
            selectedSlot: slots.isEmpty ? null : slots.first,
            clearSelectedSlot: slots.isEmpty,
          ),
        );
      },
    );
  }

  void selectSlot(TimeOfDay slot) {
    if (!state.availableSlots.contains(slot)) return;
    emit(state.copyWith(selectedSlot: slot));
  }

  Future<void> updateDuration(int newDurationMinutes) async {
    final setup = _setup;
    if (setup == null) return;

    final normalizedDuration =
        newDurationMinutes.clamp(15, 24 * 60).toInt();

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        durationMinutes: normalizedDuration,
      ),
    );

    final slotsResult = await _getQuickRebookSlots(
      loungeId: setup.lounge.id,
      roomId: setup.room.id,
      date: state.selectedDate,
      openingTime: setup.lounge.openingTime,
      closingTime: setup.lounge.closingTime,
      durationMinutes: normalizedDuration,
    );

    if (isClosed) return;

    slotsResult.fold(
      (failure) {
        emit(
          state.copyWith(
            status: QuickRebookStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (slots) {
        final selectedSlot =
            state.selectedSlot != null &&
                    slots.contains(state.selectedSlot)
                ? state.selectedSlot
                : (slots.isEmpty ? null : slots.first);

        emit(
          state.copyWith(
            status: QuickRebookStatus.ready,
            durationMinutes: normalizedDuration,
            availableSlots: slots,
            selectedSlot: selectedSlot,
            clearSelectedSlot: selectedSlot == null,
          ),
        );
      },
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
