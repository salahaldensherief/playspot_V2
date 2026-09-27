import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/my_bookings/domain/usecases/get_quick_rebook_slots_usecase.dart';
import 'package:playspot/features/my_bookings/domain/usecases/prepare_quick_rebook_usecase.dart';

import '../data/models/booking_model.dart';
import 'quick_rebook_state.dart';

class QuickRebookCubit extends Cubit<QuickRebookState> {
  final PrepareQuickRebookUseCase _prepareQuickRebookUseCase;
  final GetQuickRebookSlotsUseCase _getQuickRebookSlotsUseCase;
  final BookingRepository _bookingRepository;

  QuickRebookCubit({
    required PrepareQuickRebookUseCase prepareQuickRebookUseCase,
    required GetQuickRebookSlotsUseCase getQuickRebookSlotsUseCase,
    required BookingRepository bookingRepository,
  })  : _prepareQuickRebookUseCase = prepareQuickRebookUseCase,
        _getQuickRebookSlotsUseCase = getQuickRebookSlotsUseCase,
        _bookingRepository = bookingRepository,
        super(QuickRebookState(selectedDate: DateTime.now()));

  Future<void> initQuickRebook(BookingModel pastBooking) async {
    final selectedDate = DateTime.now();

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        pastBooking: pastBooking,
        selectedDate: selectedDate,
        clearError: true,
      ),
    );

    final preparationResult = await _prepareQuickRebookUseCase(pastBooking);
    if (isClosed) return;

    await preparationResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: QuickRebookStatus.unavailable,
            errorMessage: failure.message,
          ),
        );
      },
      (preparation) async {
        final slotsResult = await _getQuickRebookSlotsUseCase(
          loungeId: preparation.lounge.id,
          roomId: preparation.room.id,
          date: selectedDate,
          openingTime: preparation.lounge.openingTime,
          closingTime: preparation.lounge.closingTime,
          durationMinutes: preparation.durationMinutes,
        );

        if (isClosed) return;

        slotsResult.fold(
          (failure) => emit(
            state.copyWith(
              status: QuickRebookStatus.error,
              lounge: preparation.lounge,
              room: preparation.room,
              errorMessage: failure.message,
            ),
          ),
          (slots) => emit(
            state.copyWith(
              status: QuickRebookStatus.ready,
              lounge: preparation.lounge,
              room: preparation.room,
              availableExtras: preparation.availableExtras,
              selectedAddonQuantities:
                  preparation.selectedAddonQuantities,
              removedAddonNames: preparation.removedAddonNames,
              selectedDate: selectedDate,
              availableSlots: slots,
              selectedSlot: slots.isNotEmpty ? slots.first : null,
              clearSelectedSlot: slots.isEmpty,
              durationMinutes: preparation.durationMinutes,
              playMode: preparation.playMode,
              extraControllers: preparation.extraControllers,
              clearError: true,
            ),
          ),
        );
      },
    );
  }

  Future<void> changeDate(DateTime date) async {
    final lounge = state.lounge;
    final room = state.room;
    if (lounge == null || room == null) return;

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        selectedDate: date,
        clearError: true,
      ),
    );

    final result = await _getQuickRebookSlotsUseCase(
      loungeId: lounge.id,
      roomId: room.id,
      date: date,
      openingTime: lounge.openingTime,
      closingTime: lounge.closingTime,
      durationMinutes: state.durationMinutes,
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuickRebookStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (slots) => emit(
        state.copyWith(
          status: QuickRebookStatus.ready,
          availableSlots: slots,
          selectedSlot: slots.isNotEmpty ? slots.first : null,
          clearSelectedSlot: slots.isEmpty,
          clearError: true,
        ),
      ),
    );
  }

  void selectSlot(TimeOfDay slot) {
    emit(
      state.copyWith(
        selectedSlot: slot,
        clearError: true,
      ),
    );
  }

  Future<void> updateDuration(int newDurationMinutes) async {
    final lounge = state.lounge;
    final room = state.room;
    if (lounge == null || room == null) return;

    final duration = newDurationMinutes.clamp(15, 720);

    emit(
      state.copyWith(
        status: QuickRebookStatus.loading,
        durationMinutes: duration,
        clearError: true,
      ),
    );

    final result = await _getQuickRebookSlotsUseCase(
      loungeId: lounge.id,
      roomId: room.id,
      date: state.selectedDate,
      openingTime: lounge.openingTime,
      closingTime: lounge.closingTime,
      durationMinutes: duration,
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuickRebookStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (slots) {
        final selected = state.selectedSlot;
        final keepSelected =
            selected != null && slots.contains(selected);

        emit(
          state.copyWith(
            status: QuickRebookStatus.ready,
            availableSlots: slots,
            selectedSlot:
                keepSelected ? selected : (slots.isNotEmpty ? slots.first : null),
            clearSelectedSlot: !keepSelected && slots.isEmpty,
            clearError: true,
          ),
        );
      },
    );
  }

  void updateAddonQuantity(String extraId, int newQuantity) {
    final updated = Map<String, int>.from(
      state.selectedAddonQuantities,
    );

    if (newQuantity <= 0) {
      updated.remove(extraId);
    } else {
      updated[extraId] = newQuantity.clamp(1, 100);
    }

    emit(
      state.copyWith(
        selectedAddonQuantities: updated,
        clearError: true,
      ),
    );
  }

  Future<CheckoutParams?> prepareInstantCheckout({
    required bool isArabic,
  }) async {
    final lounge = state.lounge;
    final room = state.room;
    final slot = state.selectedSlot;

    if (lounge == null || room == null || slot == null) {
      return null;
    }

    final resolvedStart =
        _getQuickRebookSlotsUseCase.resolveOperationalStart(
      date: state.selectedDate,
      openingTime: lounge.openingTime,
      closingTime: lounge.closingTime,
      slot: slot,
    );

    if (resolvedStart == null) {
      emit(
        state.copyWith(
          errorMessage: 'Lounge operating hours are unavailable.',
        ),
      );
      return null;
    }

    final resolvedEnd = resolvedStart.add(
      Duration(minutes: state.durationMinutes),
    );

    emit(
      state.copyWith(
        isPreparingCheckout: true,
        clearError: true,
      ),
    );

    final holdResult = await _bookingRepository.acquireBookingHold(
      roomIds: [room.id],
      startTime: resolvedStart,
      endTime: resolvedEnd,
      holdMinutes: lounge.cashGracePeriodMinutes.clamp(1, 30),
    );

    if (isClosed) return null;

    return holdResult.fold(
      (failure) {
        emit(
          state.copyWith(
            isPreparingCheckout: false,
            errorMessage: failure.message,
          ),
        );
        return null;
      },
      (hold) {
        if (hold['success'] != true) {
          emit(
            state.copyWith(
              isPreparingCheckout: false,
              errorMessage:
                  hold['error_code']?.toString() ??
                  'overlappingBookingError',
            ),
          );
          return null;
        }

        final holdToken = hold['hold_token']?.toString();
        final holdExpiresAt = DateTime.tryParse(
          hold['hold_expires_at']?.toString() ?? '',
        );

        if (holdToken == null ||
            holdToken.isEmpty ||
            holdExpiresAt == null) {
          emit(
            state.copyWith(
              isPreparingCheckout: false,
              errorMessage: 'bookingHoldFailed',
            ),
          );
          return null;
        }

        final addons = state.selectedAddonQuantities.entries.map((entry) {
          final extra = state.availableExtras.firstWhere(
            (item) => item.id == entry.key,
          );

          return <String, dynamic>{
            'id': extra.id,
            'extra_id': extra.id,
            'name': isArabic ? extra.nameAr : extra.nameEn,
            'name_ar': extra.nameAr,
            'name_en': extra.nameEn,
            'quantity': entry.value,
            'unit_price': extra.price,
          };
        }).toList();

        final params = CheckoutParams(
          lounge: lounge,
          rooms: [room],
          roomsBreakdown: [
            {
              'roomId': room.id,
              'roomName': room.getDisplayTitle(isArabic),
              'playMode': state.playMode,
              'extraControllers': state.extraControllers,
            },
          ],
          date: state.selectedDate,
          startTime: slot,
          duration: state.durationMinutes,
          originalRoomSubtotal: 0,
          discountedRoomSubtotal: 0,
          discountAmount: 0,
          discountPercentage: 0,
          addonsTotal: 0,
          totalPrice: 0,
          originalTotalPrice: 0,
          addOns: addons,
          playMode: state.playMode,
          extraControllers: state.extraControllers,
          holdToken: holdToken,
          holdExpiresAt: holdExpiresAt,
          resolvedStartAt: resolvedStart,
        );

        emit(
          state.copyWith(
            isPreparingCheckout: false,
            clearError: true,
          ),
        );

        return params;
      },
    );
  }

  BookingDetailsParams? buildCustomizeParams({
    required bool isArabic,
  }) {
    final lounge = state.lounge;
    final room = state.room;
    if (lounge == null || room == null) return null;

    final addons = state.selectedAddonQuantities.entries.map((entry) {
      final extra = state.availableExtras.firstWhere(
        (item) => item.id == entry.key,
      );

      return <String, dynamic>{
        'id': extra.id,
        'extra_id': extra.id,
        'name': isArabic ? extra.nameAr : extra.nameEn,
        'name_ar': extra.nameAr,
        'name_en': extra.nameEn,
        'quantity': entry.value,
        'unit_price': extra.price,
      };
    }).toList();

    return BookingDetailsParams(
      lounge: lounge,
      rooms: [room],
      selectedDate: state.selectedDate,
      extras: addons,
      playMode: state.playMode,
      extraControllers: state.extraControllers,
    );
  }
}
