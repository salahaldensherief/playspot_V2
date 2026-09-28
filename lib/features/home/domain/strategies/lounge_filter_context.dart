import 'lounge_filter_strategy.dart';
import '../../data/models/lounge_model.dart';
import '../../../../art_core/exceptions/app_exceptions.dart';

class LoungeFilterContext {
  final Map<LoungeSortCriteria, LoungeFilterStrategy> _strategies = {};

  LoungeFilterContext(List<LoungeFilterStrategy> strategies) {
    for (final strategy in strategies) {
      _strategies[strategy.criteria] = strategy;
    }
  }

  void registerStrategy(LoungeFilterStrategy strategy) {
    _strategies[strategy.criteria] = strategy;
  }

  List<LoungeModel> apply({
    required LoungeSortCriteria criteria,
    required List<LoungeModel> lounges,
  }) {
    final strategy = _strategies[criteria];
    if (strategy == null) {
      throw AppException('Unsupported lounge filter criteria: $criteria');
    }
    return strategy.filterAndSort(lounges);
  }
}
