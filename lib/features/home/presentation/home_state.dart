import 'package:equatable/equatable.dart';
import '../data/models/lounge_model.dart';
import '../data/models/promo_model.dart';
import '../data/models/category_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<LoungeModel> nearestLounges;
  final List<LoungeModel> topRatedLounges;
  final List<PromoModel> promotions;
  final List<CategoryModel> categories;
  final List<Map<String, dynamic>> availableCities;
  final String? selectedCity;
  final String? currentAddress;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.nearestLounges = const [],
    this.topRatedLounges = const [],
    this.promotions = const [],
    this.categories = const [],
    this.availableCities = const [],
    this.selectedCity,
    this.currentAddress,
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<LoungeModel>? nearestLounges,
    List<LoungeModel>? topRatedLounges,
    List<PromoModel>? promotions,
    List<CategoryModel>? categories,
    List<Map<String, dynamic>>? availableCities,
    String? selectedCity,
    String? currentAddress,
    String? errorMessage,
    bool clearCity = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      nearestLounges: nearestLounges ?? this.nearestLounges,
      topRatedLounges: topRatedLounges ?? this.topRatedLounges,
      promotions: promotions ?? this.promotions,
      categories: categories ?? this.categories,
      availableCities: availableCities ?? this.availableCities,
      selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
      currentAddress: currentAddress ?? this.currentAddress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        nearestLounges,
        topRatedLounges,
        promotions,
        categories,
        availableCities,
        selectedCity,
        currentAddress,
        errorMessage,
      ];
}
