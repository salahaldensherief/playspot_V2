import '../../domain/strategies/lounge_filter_strategy.dart';
import '../../data/models/lounge_model.dart';

class RatingLoungeFilterStrategy implements LoungeFilterStrategy {
  const RatingLoungeFilterStrategy();

  @override
  LoungeSortCriteria get criteria => LoungeSortCriteria.rating;

  @override
  List<LoungeModel> filterAndSort(List<LoungeModel> lounges) {
    final sorted = List<LoungeModel>.from(lounges);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }
}
