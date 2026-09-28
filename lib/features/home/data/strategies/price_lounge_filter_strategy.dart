import '../../domain/strategies/lounge_filter_strategy.dart';
import '../../data/models/lounge_model.dart';

class PriceLoungeFilterStrategy implements LoungeFilterStrategy {
  const PriceLoungeFilterStrategy();

  @override
  LoungeSortCriteria get criteria => LoungeSortCriteria.price;

  @override
  List<LoungeModel> filterAndSort(List<LoungeModel> lounges) {
    final sorted = List<LoungeModel>.from(lounges);
    sorted.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
    return sorted;
  }
}
