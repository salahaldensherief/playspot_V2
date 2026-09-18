import '../../data/models/lounge_model.dart';

/// Enum representing available lounge sorting/filtering criteria.
enum LoungeSortCriteria { distance, rating, price, recommended }

abstract class LoungeFilterStrategy {
  LoungeSortCriteria get criteria;

  List<LoungeModel> filterAndSort(List<LoungeModel> lounges);
}
