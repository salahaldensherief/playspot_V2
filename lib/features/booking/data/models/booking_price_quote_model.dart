import '../../domain/entities/booking_price_quote.dart';

class PricingSegmentModel extends PricingSegment {
  const PricingSegmentModel({
    required super.from,
    required super.to,
    required super.minutes,
    required super.baseRate,
    super.appliedRuleId,
    required super.ruleType,
    required super.rate,
    required super.amount,
  });

  factory PricingSegmentModel.fromJson(Map<String, dynamic> json) {
    return PricingSegmentModel(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0.0,
      appliedRuleId: json['applied_rule_id']?.toString(),
      ruleType: json['rule_type']?.toString() ?? 'standard',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'minutes': minutes,
      'base_rate': baseRate,
      'applied_rule_id': appliedRuleId,
      'rule_type': ruleType,
      'rate': rate,
      'amount': amount,
    };
  }
}

class BookingPriceQuoteModel extends BookingPriceQuote {
  const BookingPriceQuoteModel({
    required super.segments,
    required super.roomSubtotal,
    required super.extraControllersAmount,
    required super.discountAmount,
    required super.total,
    super.currency = 'EGP',
    required super.hasPeak,
    required super.pricingVersion,
  });

  factory BookingPriceQuoteModel.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    final segmentsList = <PricingSegment>[];
    if (rawSegments is List) {
      for (var item in rawSegments) {
        if (item is Map) {
          segmentsList.add(PricingSegmentModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BookingPriceQuoteModel(
      segments: segmentsList,
      roomSubtotal: (json['room_subtotal'] as num?)?.toDouble() ?? 0.0,
      extraControllersAmount: (json['extra_controllers_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'EGP',
      hasPeak: json['has_peak'] == true,
      pricingVersion: (json['pricing_version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segments': segments.map((s) => (s as PricingSegmentModel).toJson()).toList(),
      'room_subtotal': roomSubtotal,
      'extra_controllers_amount': extraControllersAmount,
      'discount_amount': discountAmount,
      'total': total,
      'currency': currency,
      'has_peak': hasPeak,
      'pricing_version': pricingVersion,
    };
  }
}
