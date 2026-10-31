import 'package:playspot/core/models/geo_coordinates.dart';
import '../../data/models/lounge_model.dart';

class RecalculateLoungeDistancesUseCase {
  const RecalculateLoungeDistancesUseCase();

  List<LoungeModel> call(
    List<LoungeModel> lounges,
    GeoCoordinates? origin, {
    required bool sortByDistance,
  }) {
    final calculated = lounges.indexed.map((entry) {
      final lounge = entry.$2;
      final destination = GeoCoordinates.fromPair(lounge.lat, lounge.lng);
      final kilometers = origin != null && destination != null
          ? origin.distanceInKilometersTo(destination)
          : null;
      return (entry.$1, lounge.withDistanceEstimate(kilometers));
    }).toList();
    calculated.sort((a, b) {
      final order = sortByDistance
          ? a.$2.distance.compareTo(b.$2.distance)
          : b.$2.rating.compareTo(a.$2.rating);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
    return calculated.map((entry) => entry.$2).toList();
  }
}
