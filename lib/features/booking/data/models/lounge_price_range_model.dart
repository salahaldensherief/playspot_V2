import '../../domain/entities/lounge_price_range.dart';

class LoungePriceRangeModel extends LoungePriceRange {
  const LoungePriceRangeModel({
    required super.minHourlyRate,
    required super.maxHourlyRate,
    super.currency = 'EGP',
  });

  factory LoungePriceRangeModel.fromJson(Map<String, dynamic> json) {
    return LoungePriceRangeModel(
      minHourlyRate: (json['min_hourly_rate'] as num?)?.toDouble() ?? 0.0,
      maxHourlyRate: (json['max_hourly_rate'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'EGP',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_hourly_rate': minHourlyRate,
      'max_hourly_rate': maxHourlyRate,
      'currency': currency,
    };
  }
}
