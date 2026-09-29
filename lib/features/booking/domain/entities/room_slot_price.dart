import 'package:equatable/equatable.dart';

class RoomSlotPrice extends Equatable {
  final String slotStart;
  final String slotEnd;
  final bool isAvailable;
  final double hourlyRate;
  final String ruleType;
  final bool isPeak;

  const RoomSlotPrice({
    required this.slotStart,
    required this.slotEnd,
    required this.isAvailable,
    required this.hourlyRate,
    required this.ruleType,
    required this.isPeak,
  });

  bool get isValidPriced => hourlyRate > 0;

  @override
  List<Object?> get props => [
        slotStart,
        slotEnd,
        isAvailable,
        hourlyRate,
        ruleType,
        isPeak,
      ];
}
