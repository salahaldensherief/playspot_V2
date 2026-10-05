import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../home/data/models/lounge_model.dart';
import '../../../lounge_details/data/models/room_model.dart';

/// Parameters for navigating to the Booking Screen from Lounge Details
class BookingDetailsParams extends Equatable {
  final LoungeModel lounge;
  final List<RoomModel> rooms;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> extras;
  final String playMode;
  final int extraControllers;
  final Map<String, String> roomPlayModes;
  final Map<String, int> roomExtraControllers;

  RoomModel get room =>
      rooms.isNotEmpty ? rooms.first : throw StateError('No room in BookingDetailsParams');

  BookingDetailsParams({
    required this.lounge,
    List<RoomModel>? rooms,
    RoomModel? room,
    required this.selectedDate,
    required this.extras,
    this.playMode = 'single',
    this.extraControllers = 0,
    this.roomPlayModes = const {},
    this.roomExtraControllers = const {},
  }) : rooms = rooms ?? (room != null ? [room] : const []);

  @override
  List<Object?> get props => [
        lounge,
        rooms,
        selectedDate,
        extras,
        playMode,
        extraControllers,
        roomPlayModes,
        roomExtraControllers,
      ];

  factory BookingDetailsParams.fromMap(Map<String, dynamic> map) {
    List<RoomModel> parsedRooms = [];
    if (map['rooms'] is List) {
      parsedRooms = (map['rooms'] as List)
          .map((e) => e is RoomModel
              ? e
              : RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (map['room'] != null) {
      final r = map['room'] is RoomModel
          ? map['room'] as RoomModel
          : RoomModel.fromJson(Map<String, dynamic>.from(map['room'] as Map));
      parsedRooms = [r];
    }

    final rawModes = map['roomPlayModes'];
    final Map<String, String> modes = {};
    if (rawModes is Map) {
      rawModes.forEach((k, v) => modes[k.toString()] = v.toString());
    }

    final rawControllers = map['roomExtraControllers'];
    final Map<String, int> controllers = {};
    if (rawControllers is Map) {
      rawControllers.forEach((k, v) => controllers[k.toString()] = (v as num).toInt());
    }

    return BookingDetailsParams(
      lounge: map['lounge'] is LoungeModel
          ? map['lounge'] as LoungeModel
          : LoungeModel.fromJson(Map<String, dynamic>.from(map['lounge'] as Map)),
      rooms: parsedRooms,
      selectedDate: map['selectedDate'] is DateTime
          ? map['selectedDate'] as DateTime
          : DateTime.parse(map['selectedDate'].toString()),
      extras: map['extras'] != null
          ? (map['extras'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [],
      playMode: map['playMode']?.toString() ?? 'single',
      extraControllers: (map['extraControllers'] as num?)?.toInt() ?? 0,
      roomPlayModes: modes,
      roomExtraControllers: controllers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lounge': lounge.toJson(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      if (rooms.isNotEmpty) 'room': rooms.first.toJson(),
      'selectedDate': selectedDate.toIso8601String(),
      'extras': extras,
      'playMode': playMode,
      'extraControllers': extraControllers,
      'roomPlayModes': roomPlayModes,
      'roomExtraControllers': roomExtraControllers,
    };
  }

  factory BookingDetailsParams.fromJson(Map<String, dynamic> json) {
    return BookingDetailsParams.fromMap(json);
  }
}

/// Parameters for navigating to and initializing the Checkout Screen
class CheckoutParams extends Equatable {
  final LoungeModel lounge;
  final List<RoomModel> rooms;
  final List<Map<String, dynamic>> roomsBreakdown;
  final DateTime date;
  final TimeOfDay startTime;
  final int duration;
  final double originalRoomSubtotal;
  final double discountedRoomSubtotal;
  final double discountAmount;
  final double discountPercentage;
  final String? discountLabel;
  final String? discountSource;
  final double addonsTotal;
  final double totalPrice;
  final double originalTotalPrice;
  final List<Map<String, dynamic>> addOns;
  final String? playMode;
  final double? appliedHourlyRate;
  final int? extraControllers;
  final double? extraControllerPrice;
  final String? holdToken;
  final DateTime? holdExpiresAt;
  final DateTime? resolvedStartAt;

  RoomModel get room =>
      rooms.isNotEmpty ? rooms.first : throw StateError('No room in CheckoutParams');

  double get extraControllersChargePerHour =>
      (extraControllers ?? 0) * (extraControllerPrice ?? 0.0);

  DateTime get effectiveStartAt =>
      resolvedStartAt ??
      DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

  CheckoutParams({
    required this.lounge,
    List<RoomModel>? rooms,
    RoomModel? room,
    this.roomsBreakdown = const [],
    required this.date,
    required this.startTime,
    required this.duration,
    required this.originalRoomSubtotal,
    required this.discountedRoomSubtotal,
    required this.discountAmount,
    required this.discountPercentage,
    this.discountLabel,
    this.discountSource,
    required this.addonsTotal,
    required this.totalPrice,
    required this.originalTotalPrice,
    required this.addOns,
    this.playMode,
    this.appliedHourlyRate,
    this.extraControllers,
    this.extraControllerPrice,
    this.holdToken,
    this.holdExpiresAt,
    this.resolvedStartAt,
  }) : rooms = rooms ?? (room != null ? [room] : const []);

  @override
  List<Object?> get props => [
        lounge,
        rooms,
        roomsBreakdown,
        date,
        startTime,
        duration,
        originalRoomSubtotal,
        discountedRoomSubtotal,
        discountAmount,
        discountPercentage,
        discountLabel,
        discountSource,
        addonsTotal,
        totalPrice,
        originalTotalPrice,
        addOns,
        playMode,
        appliedHourlyRate,
        extraControllers,
        extraControllerPrice,
        holdToken,
        holdExpiresAt,
        resolvedStartAt,
      ];

  factory CheckoutParams.fromMap(Map<String, dynamic> map) {
    final rawStartTime = map['startTime'];
    TimeOfDay parsedStartTime;
    if (rawStartTime is TimeOfDay) {
      parsedStartTime = rawStartTime;
    } else if (rawStartTime is Map) {
      parsedStartTime = TimeOfDay(
        hour: (rawStartTime['hour'] as num).toInt(),
        minute: (rawStartTime['minute'] as num).toInt(),
      );
    } else if (rawStartTime is String) {
      final parts = rawStartTime.split(':');
      parsedStartTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      parsedStartTime = const TimeOfDay(hour: 0, minute: 0);
    }

    final double totPrice = (map['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final double origTotPrice = (map['originalTotalPrice'] as num?)?.toDouble() ?? totPrice;

    List<RoomModel> parsedRooms = [];
    if (map['rooms'] is List) {
      parsedRooms = (map['rooms'] as List)
          .map((e) => e is RoomModel
              ? e
              : RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (map['room'] != null) {
      final r = map['room'] is RoomModel
          ? map['room'] as RoomModel
          : RoomModel.fromJson(Map<String, dynamic>.from(map['room'] as Map));
      parsedRooms = [r];
    }

    final List<Map<String, dynamic>> breakdown = map['roomsBreakdown'] != null
        ? (map['roomsBreakdown'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : [];

    return CheckoutParams(
      lounge: map['lounge'] is LoungeModel
          ? map['lounge'] as LoungeModel
          : LoungeModel.fromJson(Map<String, dynamic>.from(map['lounge'] as Map)),
      rooms: parsedRooms,
      roomsBreakdown: breakdown,
      date: map['date'] is DateTime
          ? map['date'] as DateTime
          : DateTime.parse(map['date'].toString()),
      startTime: parsedStartTime,
      duration: (map['duration'] as num?)?.toInt() ?? 60,
      originalRoomSubtotal: (map['originalRoomSubtotal'] as num?)?.toDouble() ?? origTotPrice,
      discountedRoomSubtotal: (map['discountedRoomSubtotal'] as num?)?.toDouble() ?? totPrice,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? (origTotPrice - totPrice).clamp(0.0, double.infinity),
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      discountLabel: map['discountLabel']?.toString(),
      discountSource: map['discountSource']?.toString() ?? 'none',
      addonsTotal: (map['addonsTotal'] as num?)?.toDouble() ?? 0.0,
      totalPrice: totPrice,
      originalTotalPrice: origTotPrice,
      addOns: map['addOns'] != null
          ? (map['addOns'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [],
      playMode: map['playMode']?.toString() ?? map['play_mode']?.toString(),
      appliedHourlyRate: (map['appliedHourlyRate'] as num?)?.toDouble(),
      extraControllers: (map['extraControllers'] as num?)?.toInt(),
      extraControllerPrice: (map['extraControllerPrice'] as num?)?.toDouble(),
      holdToken: map['holdToken']?.toString(),
      holdExpiresAt: map['holdExpiresAt'] != null
          ? DateTime.tryParse(map['holdExpiresAt'].toString())
          : null,
      resolvedStartAt: map['resolvedStartAt'] != null
          ? DateTime.tryParse(map['resolvedStartAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lounge': lounge.toJson(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      if (rooms.isNotEmpty) 'room': rooms.first.toJson(),
      'roomsBreakdown': roomsBreakdown,
      'date': date.toIso8601String(),
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'duration': duration,
      'originalRoomSubtotal': originalRoomSubtotal,
      'discountedRoomSubtotal': discountedRoomSubtotal,
      'discountAmount': discountAmount,
      'discountPercentage': discountPercentage,
      'discountLabel': discountLabel,
      'discountSource': discountSource,
      'addonsTotal': addonsTotal,
      'totalPrice': totalPrice,
      'originalTotalPrice': originalTotalPrice,
      'addOns': addOns,
      'playMode': playMode,
      'play_mode': playMode,
      'appliedHourlyRate': appliedHourlyRate,
      'extraControllers': extraControllers,
      'extraControllerPrice': extraControllerPrice,
      'holdToken': holdToken,
      'holdExpiresAt': holdExpiresAt?.toIso8601String(),
      'resolvedStartAt': resolvedStartAt?.toIso8601String(),
    };
  }

  factory CheckoutParams.fromJson(Map<String, dynamic> json) {
    return CheckoutParams.fromMap(json);
  }
}

/// Consolidated pricing extensions for [CheckoutParams] across UI and submission flows
extension CheckoutPricingX on CheckoutParams {
  /// Calculates final payable price after applying voucher discount, clamped to >= 0.0.
  double calculateFinalPrice(double voucherDiscount) {
    return (totalPrice - voucherDiscount).clamp(0.0, double.infinity);
  }

  /// Calculates room final price for a specific room breakdown / room index after applying voucher discount on primary room.
  double calculateRoomTotalPrice({
    required double discountedRoomPrice,
    required double roomAddonsTotal,
    required double voucherDiscount,
    required bool isPrimaryRoom,
  }) {
    final double rawPrice = discountedRoomPrice + roomAddonsTotal - (isPrimaryRoom ? voucherDiscount : 0.0);
    return rawPrice.clamp(0.0, double.infinity);
  }
}

