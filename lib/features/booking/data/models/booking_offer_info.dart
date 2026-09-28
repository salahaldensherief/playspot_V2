import 'package:equatable/equatable.dart';
import '../../../home/data/models/lounge_model.dart';
import '../../../lounge_details/data/models/room_model.dart';

class BookingOfferInfo extends Equatable {
  final double originalHourlyRate;
  final double discountedHourlyRate;
  final double hourlyDiscountAmount;
  final double discountPercentage;
  final String? discountLabel;
  final String discountSource; // 'room', 'lounge', or 'none'
  final bool hasOffer;

  const BookingOfferInfo({
    required this.originalHourlyRate,
    required this.discountedHourlyRate,
    required this.hourlyDiscountAmount,
    required this.discountPercentage,
    this.discountLabel,
    required this.discountSource,
    required this.hasOffer,
  });

  @override
  List<Object?> get props => [
        originalHourlyRate,
        discountedHourlyRate,
        hourlyDiscountAmount,
        discountPercentage,
        discountLabel,
        discountSource,
        hasOffer,
      ];

  /// Priority Rules:
  /// 1. Direct Room Offer (`room.hasActivePromo && room.promoDiscountValue > 0`)
  /// 2. Lounge Offer (`lounge.isDiscountActive && lounge.discountPercentage > 0`)
  /// 3. Standard Price (No offer)
  factory BookingOfferInfo.resolve({
    required RoomModel room,
    required LoungeModel lounge,
    required bool isSinglePlay,
    required bool isArabic,
  }) {
    final originalRate = isSinglePlay ? room.hourlyRateSingle : room.hourlyRateMulti;

    // Priority 1: Direct Room Offer
    if (room.hasActivePromo && room.promoDiscountValue > 0) {
      double discountedRate = originalRate;
      double percentage = 0.0;
      double discountAmount = 0.0;

      if (room.promoDiscountType == 'percentage') {
        percentage = room.promoDiscountValue;
        discountedRate = originalRate * (1 - (room.promoDiscountValue / 100.0));
        discountAmount = originalRate - discountedRate;
      } else {
        discountAmount = room.promoDiscountValue;
        discountedRate = (originalRate - room.promoDiscountValue).clamp(0.0, double.infinity);
        percentage = originalRate > 0 ? ((discountAmount / originalRate) * 100.0) : 0.0;
      }

      final label = room.getPromoTag(isArabic) ?? (isArabic ? "عرض الغرفة" : "Room Offer");

      return BookingOfferInfo(
        originalHourlyRate: originalRate,
        discountedHourlyRate: discountedRate,
        hourlyDiscountAmount: discountAmount,
        discountPercentage: percentage,
        discountLabel: label,
        discountSource: 'room',
        hasOffer: true,
      );
    }

    // Priority 2: Lounge Offer (applies to room)
    if (lounge.isDiscountActive && lounge.discountPercentage > 0) {
      final percentage = lounge.discountPercentage.toDouble();
      final discountedRate = originalRate * (1 - (percentage / 100.0));
      final discountAmount = originalRate - discountedRate;
      final label = lounge.getDiscountTitle(isArabic) ??
          (isArabic ? "عرض الصالة $percentage%" : "Lounge Offer $percentage%");

      return BookingOfferInfo(
        originalHourlyRate: originalRate,
        discountedHourlyRate: discountedRate,
        hourlyDiscountAmount: discountAmount,
        discountPercentage: percentage,
        discountLabel: label,
        discountSource: 'lounge',
        hasOffer: true,
      );
    }

    // Priority 3: Standard Price (No active offer)
    return BookingOfferInfo(
      originalHourlyRate: originalRate,
      discountedHourlyRate: originalRate,
      hourlyDiscountAmount: 0.0,
      discountPercentage: 0.0,
      discountLabel: null,
      discountSource: 'none',
      hasOffer: false,
    );
  }

  /// Helper to compute totals for a specific duration in minutes and extra controllers
  Map<String, double> calculateSubtotals({
    required int durationMinutes,
    required int extraControllersCount,
    required double extraControllerPrice,
    required List<Map<String, dynamic>> extras,
  }) {
    final durationHours = durationMinutes / 60.0;
    final controllersRate = extraControllersCount * extraControllerPrice;

    final originalRoomSubtotal = (originalHourlyRate + controllersRate) * durationHours;
    final discountedRoomSubtotal = (discountedHourlyRate + controllersRate) * durationHours;
    final roomDiscountAmount = originalRoomSubtotal - discountedRoomSubtotal;

    final addonsTotal = extras.fold<double>(
      0.0,
      (sum, item) => sum + (((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 1.0)),
    );

    final totalPrice = discountedRoomSubtotal + addonsTotal;
    final originalTotalPrice = originalRoomSubtotal + addonsTotal;

    return {
      'originalRoomSubtotal': originalRoomSubtotal,
      'discountedRoomSubtotal': discountedRoomSubtotal,
      'roomDiscountAmount': roomDiscountAmount,
      'addonsTotal': addonsTotal,
      'totalPrice': totalPrice,
      'originalTotalPrice': originalTotalPrice,
      'durationHours': durationHours,
    };
  }
}
