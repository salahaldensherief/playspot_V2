import 'package:equatable/equatable.dart';
import '../data/models/lounge_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<LoungeModel> nearestLounges;
  final List<LoungeModel> topRatedLounges;
  final List<Map<String, dynamic>> availableCities;
  final String? selectedCity;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.nearestLounges = const [],
    this.topRatedLounges = const [],
    this.availableCities = const [],
    this.selectedCity,
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<LoungeModel>? nearestLounges,
    List<LoungeModel>? topRatedLounges,
    List<Map<String, dynamic>>? availableCities,
    String? selectedCity,
    String? errorMessage,
    bool clearCity = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      nearestLounges: nearestLounges ?? this.nearestLounges,
      topRatedLounges: topRatedLounges ?? this.topRatedLounges,
      availableCities: availableCities ?? this.availableCities,
      selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        nearestLounges,
        topRatedLounges,
        availableCities,
        selectedCity,
        errorMessage,
      ];
}
