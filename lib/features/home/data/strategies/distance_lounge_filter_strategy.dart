import '../../domain/strategies/lounge_filter_strategy.dart';
import '../../data/models/lounge_model.dart';

class DistanceLoungeFilterStrategy implements LoungeFilterStrategy {
  const DistanceLoungeFilterStrategy();

  @override
  LoungeSortCriteria get criteria => LoungeSortCriteria.distance;

  @override
  List<LoungeModel> filterAndSort(List<LoungeModel> lounges) {
    final sorted = List<LoungeModel>.from(lengesComparator(lounges));
    sorted.sort((a, b) => a.distance.compareTo(b.distance));
    return sorted;
  }

  Iterable<LoungeModel> lengesComparator(List<LoungeModel> lounges) => lounges;
}
