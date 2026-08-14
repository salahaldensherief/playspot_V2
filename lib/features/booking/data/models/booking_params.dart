import 'package:flutter/material.dart';
import '../../../home/data/models/lounge_model.dart';
import '../../../lounge_details/data/models/room_model.dart';

/// Parameters for navigating to the Booking Screen from Lounge Details
class BookingDetailsParams {
  final LoungeModel lounge;
  final RoomModel room;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> extras;
  final String playMode;
  final int extraControllers;

  BookingDetailsParams({
    required this.lounge,
    required this.room,
    required this.selectedDate,
    required this.extras,
    required this.playMode,
    required this.extraControllers,
  });

  factory BookingDetailsParams.fromMap(Map<String, dynamic> map) {
    return BookingDetailsParams(
      lounge: map['lounge'] as LoungeModel,
      room: map['room'] as RoomModel,
      selectedDate: map['selectedDate'] as DateTime,
      extras: List<Map<String, dynamic>>.from(map['extras'] ?? []),
      playMode: map['playMode']?.toString() ?? 'single',
      extraControllers: map['extraControllers'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lounge': lounge,
      'room': room,
      'selectedDate': selectedDate,
      'extras': extras,
      'playMode': playMode,
      'extraControllers': extraControllers,
    };
  }
}

/// Parameters for creating a booking in the repository/data source
class CreateBookingParams {
  final String roomId;
  final String roomName;
  final String loungeId;
  final String userName;
  final String userPhone;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final double roomPrice;
  final List<Map<String, dynamic>> addOns;
  final String? playMode;
  final int? extraControllers;

  CreateBookingParams({
    required this.roomId,
    required this.roomName,
    required this.loungeId,
    required this.userName,
    required this.userPhone,
    required DateTime startTime,
    required DateTime endTime,
    required this.totalPrice,
    required this.roomPrice,
    this.addOns = const [],
    this.playMode,
    this.extraControllers,
  }) : startTime = startTime.toUtc(),
       endTime = endTime.toUtc();

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'lounge_id': loungeId,
      'user_name': userName,
      'user_phone': userPhone,
      'start_at': startTime.toIso8601String(),
      'end_at': endTime.toIso8601String(),
      'total_price': totalPrice,
      'room_price': roomPrice,
      'extras': addOns,
      'play_mode': playMode,
      'extra_controllers': extraControllers,
    };
  }
}

/// Parameters for navigating to and initializing the Checkout Screen
class CheckoutParams {
  final LoungeModel lounge;
  final RoomModel room;
  final DateTime date;
  final TimeOfDay startTime;
  final int duration;
  final double totalPrice;
  final List<Map<String, dynamic>> addOns;
  final String? playMode;
  final double? appliedHourlyRate;
  final int? extraControllers;
  final double? extraControllerPrice;

  CheckoutParams({
    required this.lounge,
    required this.room,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.totalPrice,
    required this.addOns,
    this.playMode,
    this.appliedHourlyRate,
    this.extraControllers,
    this.extraControllerPrice,
  });

  factory CheckoutParams.fromMap(Map<String, dynamic> map) {
    return CheckoutParams(
      lounge: map['lounge'] as LoungeModel,
      room: map['room'] as RoomModel,
      date: map['date'] as DateTime,
      startTime: map['startTime'] as TimeOfDay,
      duration: map['duration'] as int,
      totalPrice: (map['totalPrice'] as num).toDouble(),
      addOns: List<Map<String, dynamic>>.from(map['addOns'] ?? []),
      playMode: map['playMode']?.toString(),
      appliedHourlyRate: (map['appliedHourlyRate'] as num?)?.toDouble(),
      extraControllers: map['extraControllers'] as int?,
      extraControllerPrice: (map['extraControllerPrice'] as num?)?.toDouble(),
    );
  }
}
