import 'package:equatable/equatable.dart';

class PricingSegment extends Equatable {
  final String from;
  final String to;
  final int minutes;
  final double baseRate;
  final String? appliedRuleId;
  final String ruleType;
  final double rate;
  final double amount;

  const PricingSegment({
    required this.from,
    required this.to,
    required this.minutes,
    required this.baseRate,
    this.appliedRuleId,
    required this.ruleType,
    required this.rate,
    required this.amount,
  });

  bool get isPeak => ruleType.toLowerCase().trim() == 'peak';

  @override
  List<Object?> get props => [
        from,
        to,
        minutes,
        baseRate,
        appliedRuleId,
        ruleType,
        rate,
        amount,
      ];
}

class BookingPriceQuote extends Equatable {
  final List<PricingSegment> segments;
  final double roomSubtotal;
  final double extraControllersAmount;
  final double discountAmount;
  final double total;
  final String currency;
  final bool hasPeak;
  final int pricingVersion;

  const BookingPriceQuote({
    required this.segments,
    required this.roomSubtotal,
    required this.extraControllersAmount,
    required this.discountAmount,
    required this.total,
    this.currency = 'EGP',
    required this.hasPeak,
    required this.pricingVersion,
  });

  @override
  List<Object?> get props => [
        segments,
        roomSubtotal,
        extraControllersAmount,
        discountAmount,
        total,
        currency,
        hasPeak,
        pricingVersion,
      ];
}
