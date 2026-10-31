import 'package:equatable/equatable.dart';

class LoungePriceRange extends Equatable {
  final double minHourlyRate;
  final double maxHourlyRate;
  final String currency;

  const LoungePriceRange({
    required this.minHourlyRate,
    required this.maxHourlyRate,
    this.currency = 'EGP',
  });

  String get formattedRangeAr {
    final minStr = minHourlyRate.toStringAsFixed(0);
    final maxStr = maxHourlyRate.toStringAsFixed(0);
    if (minHourlyRate == maxHourlyRate || maxHourlyRate == 0) {
      return "من $minStr ج.م/ساعة";
    }
    return "من $minStr - $maxStr ج.م/ساعة";
  }

  String get formattedRangeEn {
    final minStr = minHourlyRate.toStringAsFixed(0);
    final maxStr = maxHourlyRate.toStringAsFixed(0);
    if (minHourlyRate == maxHourlyRate || maxHourlyRate == 0) {
      return "From $minStr EGP/hr";
    }
    return "From $minStr - $maxStr EGP/hr";
  }

  @override
  List<Object?> get props => [minHourlyRate, maxHourlyRate, currency];
}
