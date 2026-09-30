import 'package:equatable/equatable.dart';

class SlotWaitlistResult extends Equatable {
  final bool isSuccess;
  final bool isPartial;
  final int successfulRoomsCount;
  final int failedRoomsCount;
  final String? message;

  const SlotWaitlistResult({
    required this.isSuccess,
    this.isPartial = false,
    this.successfulRoomsCount = 0,
    this.failedRoomsCount = 0,
    this.message,
  });

  @override
  List<Object?> get props => [
        isSuccess,
        isPartial,
        successfulRoomsCount,
        failedRoomsCount,
        message,
      ];
}
