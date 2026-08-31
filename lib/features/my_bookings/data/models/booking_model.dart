import 'package:equatable/equatable.dart';

class BookingModel extends Equatable {
  final String id;
  final String loungeName;
  final String loungeLocation;
  final String roomName;
  final String? spaceType;
  final String? spaceTypeName;
  final int controllersCount;
  final String screenSize;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status; // upcoming, past, cancelled
  final String paymentStatus; // unpaid, paid, refunded, partially_paid
  final double totalPrice;
  final String? playMode;
  final String? mapsLink;
  final double? lat;
  final double? lng;

  const BookingModel({
    required this.id,
    required this.loungeName,
    required this.loungeLocation,
    required this.roomName,
    this.spaceType,
    this.spaceTypeName,
    required this.controllersCount,
    required this.screenSize,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.paymentStatus,
    required this.totalPrice,
    this.playMode,
    this.mapsLink,
    this.lat,
    this.lng,
  });

  @override
  List<Object?> get props => [
        id,
        loungeName,
        loungeLocation,
        roomName,
        spaceType,
        spaceTypeName,
        controllersCount,
        screenSize,
        date,
        startTime,
        endTime,
        status,
        paymentStatus,
        totalPrice,
        playMode,
        mapsLink,
        lat,
        lng,
      ];

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final loungeData = json['lounges'] as Map<String, dynamic>?;
    final roomData = json['rooms'] as Map<String, dynamic>?;

    return BookingModel(
      id: json['id'].toString(),
      loungeName: loungeData?['name'] ?? '',
      loungeLocation: loungeData?['location'] ?? '',
      roomName: roomData?['name_en'] ?? roomData?['name'] ?? '',
      spaceType: roomData?['space_types']?['label'],
      spaceTypeName: roomData?['space_types']?['name'],
      controllersCount: roomData?['controllers_count'] ?? 0,
      screenSize: roomData?['screen_size'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : (json['time_range'] != null ? _parseTsRangeStart(json['time_range'].toString()) : DateTime.now()),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: json['status'] ?? 'past',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      playMode: json['play_mode'],
      mapsLink: loungeData?['maps_link'],
      lat: (loungeData?['lat'] as num?)?.toDouble(),
      lng: (loungeData?['lng'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseTsRangeStart(String rangeStr) {
    try {
      final cleanStr = rangeStr.replaceAll(RegExp(r'[\"\[\]\)]'), '');
      final parts = cleanStr.split(',');
      if (parts.isNotEmpty) {
        return DateTime.parse(parts[0].trim());
      }
    } catch (_) {}
    return DateTime.now();
  }
}
