import 'package:equatable/equatable.dart';
import 'booking_json_decoder.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/models/payment_model.dart';

class BookingModel extends Equatable {
  final String id;
  final String? loungeId;
  final String? roomId;
  final String loungeName;
  final String loungeLocation;
  final String roomName;
  final String? spaceType;
  final String? spaceTypeName;
  final int controllersCount;
  final int extraControllers;
  final String screenSize;
  final DateTime date;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final String paymentStatus; // unpaid, paid, refunded, partially_paid
  final double totalPrice;
  final String? playMode;
  final String? mapsLink;
  final double? lat;
  final double? lng;
  final DateTime startDateTime;
  final List<Map<String, dynamic>> canteenItems;
  final String? paymentMethod;
  final bool? isFirstBooking;
  final DateTime? checkedInAt;
  final String? cancellationReason;
  final String? senderAccount;
  final String? transactionReference;
  final String? proofImageUrl;
  final DateTime? holdExpiresAt;
  final String? rejectionReason;
  final DateTime? paidAt;
  final PaymentModel? payment;

  const BookingModel({
    required this.id,
    this.loungeId,
    this.roomId,
    required this.loungeName,
    required this.loungeLocation,
    required this.roomName,
    this.spaceType,
    this.spaceTypeName,
    required this.controllersCount,
    this.extraControllers = 0,
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
    required this.startDateTime,
    this.canteenItems = const [],
    this.paymentMethod,
    this.isFirstBooking,
    this.checkedInAt,
    this.cancellationReason,
    this.senderAccount,
    this.transactionReference,
    this.proofImageUrl,
    this.holdExpiresAt,
    this.rejectionReason,
    this.paidAt,
    this.payment,
  });

  bool get isUpcoming =>
      status == BookingStatus.upcoming || status == BookingStatus.pending;
  bool get hasCanteenOrders => canteenItems.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    loungeId,
    roomId,
    loungeName,
    loungeLocation,
    roomName,
    spaceType,
    spaceTypeName,
    controllersCount,
    extraControllers,
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
    startDateTime,
    canteenItems,
    paymentMethod,
    isFirstBooking,
    checkedInAt,
    cancellationReason,
    senderAccount,
    transactionReference,
    proofImageUrl,
    holdExpiresAt,
    rejectionReason,
    paidAt,
    payment,
  ];

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      BookingJsonDecoder.decode(json);
}
