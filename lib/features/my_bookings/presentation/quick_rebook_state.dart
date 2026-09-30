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
  final Map<String, int> selectedAddonQuantities; // extraId -> qty
  final List<String> removedAddonNames;
  final DateTime selectedDate;
  final List<TimeOfDay> availableSlots;
  final TimeOfDay? selectedSlot;
  final List<DateTime> suggestedDates;
  final int durationMinutes;
  final double roomSubtotal;
  final double addonsTotal;
  final double totalPrice;
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
    this.suggestedDates = const [],
    this.durationMinutes = 60,
    this.roomSubtotal = 0.0,
    this.addonsTotal = 0.0,
    this.totalPrice = 0.0,
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
    List<DateTime>? suggestedDates,
    int? durationMinutes,
    double? roomSubtotal,
    double? addonsTotal,
    double? totalPrice,
    String? errorMessage,
  }) {
    return QuickRebookState(
      status: status ?? this.status,
      pastBooking: pastBooking ?? this.pastBooking,
      lounge: lounge ?? this.lounge,
      room: room ?? this.room,
      availableExtras: availableExtras ?? this.availableExtras,
      selectedAddonQuantities: selectedAddonQuantities ?? this.selectedAddonQuantities,
      removedAddonNames: removedAddonNames ?? this.removedAddonNames,
      selectedDate: selectedDate ?? this.selectedDate,
      availableSlots: availableSlots ?? this.availableSlots,
      selectedSlot: clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
      suggestedDates: suggestedDates ?? this.suggestedDates,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      roomSubtotal: roomSubtotal ?? this.roomSubtotal,
      addonsTotal: addonsTotal ?? this.addonsTotal,
      totalPrice: totalPrice ?? this.totalPrice,
      errorMessage: errorMessage ?? this.errorMessage,
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
        suggestedDates,
        durationMinutes,
        roomSubtotal,
        addonsTotal,
        totalPrice,
        errorMessage,
      ];
}
