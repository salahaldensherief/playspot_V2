import 'package:equatable/equatable.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class LoungeComparisonFacts extends Equatable {
  final int roomCount;
  final int maxCapacity;
  final double? minimumBaseRate;
  final List<String> features;
  final List<String> activities;
  const LoungeComparisonFacts({
    required this.roomCount,
    required this.maxCapacity,
    required this.minimumBaseRate,
    required this.features,
    required this.activities,
  });

  factory LoungeComparisonFacts.fromRooms(
    List<RoomModel> rooms, {
    required bool isArabic,
  }) {
    var capacity = 0;
    double? rate;
    final features = <String>{};
    final activities = <String>{};
    for (final room in rooms) {
      if (room.maxCapacity > capacity) capacity = room.maxCapacity;
      if (room.hourlyRateSingle > 0 &&
          (rate == null || room.hourlyRateSingle < rate)) {
        rate = room.hourlyRateSingle;
      }
      features.addAll(room.getFeatures(isArabic));
      activities.addAll(
        room.activityNames.map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }
    return LoungeComparisonFacts(
      roomCount: rooms.length,
      maxCapacity: capacity,
      minimumBaseRate: rate,
      features: features.toList(),
      activities: activities.toList(),
    );
  }

  @override
  List<Object?> get props => [
    roomCount,
    maxCapacity,
    minimumBaseRate,
    features,
    activities,
  ];
}
