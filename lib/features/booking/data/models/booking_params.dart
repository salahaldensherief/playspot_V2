import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/booking_status.dart';
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

/// Parameters for creating a booking in the repository/data source
class CreateBookingParams extends Equatable {
  final String roomId;
  final String roomName;
  final String loungeId;
  final String userName;
  final String userPhone;
  final DateTime startTime;
  final DateTime endTime;
  final double originalRoomPrice;
  final double discountedRoomPrice;
  final double roomPrice;
  final double discountAmount;
  final double discountPercentage;
  final String? discountLabel;
  final String? discountReason;
  final String? discountSource;
  final double durationHours;
  final double roomSubtotal;
  final double addonsTotal;
  final double totalPrice;
  final List<Map<String, dynamic>> addOns;
  final String? playMode;
  final String status;
  final String paymentStatus;
  final String? receiptUrl;
  final String? paymentMethod;
  final String? senderWalletPhone;
  final DateTime? expiresAt;

  const CreateBookingParams({
    required this.roomId,
    required this.roomName,
    required this.loungeId,
    required this.userName,
    required this.userPhone,
    required this.startTime,
    required this.endTime,
    required this.originalRoomPrice,
    required this.discountedRoomPrice,
    required this.roomPrice,
    this.discountAmount = 0.0,
    this.discountPercentage = 0.0,
    this.discountLabel,
    this.discountReason,
    this.discountSource,
    required this.durationHours,
    required this.roomSubtotal,
    required this.addonsTotal,
    required this.totalPrice,
    this.addOns = const [],
    this.playMode,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.receiptUrl,
    this.paymentMethod,
    this.senderWalletPhone,
    this.expiresAt,
  });

  @override
  List<Object?> get props => [
        roomId,
        roomName,
        loungeId,
        userName,
        userPhone,
        startTime,
        endTime,
        originalRoomPrice,
        discountedRoomPrice,
        roomPrice,
        discountAmount,
        discountPercentage,
        discountLabel,
        discountReason,
        discountSource,
        durationHours,
        roomSubtotal,
        addonsTotal,
        totalPrice,
        addOns,
        playMode,
        status,
        paymentStatus,
        receiptUrl,
        paymentMethod,
        senderWalletPhone,
        expiresAt,
      ];

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'lounge_id': loungeId,
      'user_name': userName,
      'user_phone': userPhone,
      'start_at': startTime.toIso8601String(),
      'end_at': endTime.toIso8601String(),
      'start_time': "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}",
      'end_time': "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:${endTime.second.toString().padLeft(2, '0')}",
      'original_room_price': originalRoomPrice,
      'discounted_room_price': discountedRoomPrice,
      'room_price': discountedRoomPrice,
      'discount_amount': discountAmount,
      'discount_percentage': discountPercentage,
      'discount_label': discountLabel,
      'discount_reason': discountReason ?? discountLabel,
      'discount_source': discountSource,
      'duration_hours': durationHours,
      'room_subtotal': roomSubtotal,
      'addons_total': addonsTotal,
      'total_price': totalPrice,
      'extras': addOns,
      'play_mode': playMode,
      'status': BookingStatus.mapToDbStatus(status),
      'payment_status': paymentStatus,
    };
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

  RoomModel get room =>
      rooms.isNotEmpty ? rooms.first : throw StateError('No room in CheckoutParams');

  double get extraControllersChargePerHour =>
      (extraControllers ?? 0) * (extraControllerPrice ?? 0.0);

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
    };
  }

  factory CheckoutParams.fromJson(Map<String, dynamic> json) {
    return CheckoutParams.fromMap(json);
  }
}
