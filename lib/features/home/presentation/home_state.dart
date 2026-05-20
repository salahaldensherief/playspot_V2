import 'package:equatable/equatable.dart';
import '../data/models/lounge_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<LoungeModel> nearestLounges;
  final List<LoungeModel> topRatedLounges;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.nearestLounges = const [],
    this.topRatedLounges = const [],
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<LoungeModel>? nearestLounges,
    List<LoungeModel>? topRatedLounges,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      nearestLounges: nearestLounges ?? this.nearestLounges,
      topRatedLounges: topRatedLounges ?? this.topRatedLounges,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, nearestLounges, topRatedLounges, errorMessage];
}
