import '../../domain/entities/room_slot_price.dart';

class RoomSlotPriceModel extends RoomSlotPrice {
  const RoomSlotPriceModel({
    required super.slotStart,
    required super.slotEnd,
    required super.isAvailable,
    required super.hourlyRate,
    required super.ruleType,
    required super.isPeak,
  });

  factory RoomSlotPriceModel.fromJson(Map<String, dynamic> json) {
    final rate = (json['hourly_rate'] as num?)?.toDouble() ?? 0.0;
    final rType = json['rule_type']?.toString() ?? 'standard';
    final rawPeak = json['is_peak'];
    final computedIsPeak = rawPeak == true || rType.toLowerCase().trim() == 'peak';

    return RoomSlotPriceModel(
      slotStart: json['slot_start']?.toString() ?? '',
      slotEnd: json['slot_end']?.toString() ?? '',
      isAvailable: json['is_available'] == true,
      hourlyRate: rate,
      ruleType: rType,
      isPeak: computedIsPeak,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot_start': slotStart,
      'slot_end': slotEnd,
      'is_available': isAvailable,
      'hourly_rate': hourlyRate,
      'rule_type': ruleType,
      'is_peak': isPeak,
    };
  }
}
