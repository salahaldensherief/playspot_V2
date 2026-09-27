import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../data/models/booking_model.dart';

enum QuickRebookStatus { initial, loading, ready, unavailable, error }

class QuickRebookState extends Equatable {
  final QuickRebookStatus status;
  final BookingModel? pastBooking;
  final LoungeModel? lounge;
  final RoomModel? room;
  final List<ExtraModel> availableExtras;
  final Map<String, int> selectedAddonQuantities;
  final List<String> removedAddonNames;
  final DateTime selectedDate;
  final List<TimeOfDay> availableSlots;
  final TimeOfDay? selectedSlot;
  final int durationMinutes;
  final String playMode;
  final int extraControllers;
  final bool isPreparingCheckout;
  final String? errorMessage;

  const QuickRebookState({
    this.status = QuickRebookStatus.initial,
    this.pastBooking,
    this.lounge,
    this.room,
    this.availableExtras = const [],
    this.selectedAddonQuantities = const {},
    this.removedAddonNames = const [],
    required this.selectedDate,
    this.availableSlots = const [],
    this.selectedSlot,
    this.durationMinutes = 60,
    this.playMode = 'single',
    this.extraControllers = 0,
    this.isPreparingCheckout = false,
    this.errorMessage,
  });

  QuickRebookState copyWith({
    QuickRebookStatus? status,
    BookingModel? pastBooking,
    LoungeModel? lounge,
    RoomModel? room,
    List<ExtraModel>? availableExtras,
    Map<String, int>? selectedAddonQuantities,
    List<String>? removedAddonNames,
    DateTime? selectedDate,
    List<TimeOfDay>? availableSlots,
    TimeOfDay? selectedSlot,
    bool clearSelectedSlot = false,
    int? durationMinutes,
    String? playMode,
    int? extraControllers,
    bool? isPreparingCheckout,
    String? errorMessage,
    bool clearError = false,
  }) {
    return QuickRebookState(
      status: status ?? this.status,
      pastBooking: pastBooking ?? this.pastBooking,
      lounge: lounge ?? this.lounge,
      room: room ?? this.room,
      availableExtras: availableExtras ?? this.availableExtras,
      selectedAddonQuantities:
          selectedAddonQuantities ?? this.selectedAddonQuantities,
      removedAddonNames: removedAddonNames ?? this.removedAddonNames,
      selectedDate: selectedDate ?? this.selectedDate,
      availableSlots: availableSlots ?? this.availableSlots,
      selectedSlot:
          clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      playMode: playMode ?? this.playMode,
      extraControllers: extraControllers ?? this.extraControllers,
      isPreparingCheckout:
          isPreparingCheckout ?? this.isPreparingCheckout,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        pastBooking,
        lounge,
        room,
        availableExtras,
        selectedAddonQuantities,
        removedAddonNames,
        selectedDate,
        availableSlots,
        selectedSlot,
        durationMinutes,
        playMode,
        extraControllers,
        isPreparingCheckout,
        errorMessage,
      ];
}
