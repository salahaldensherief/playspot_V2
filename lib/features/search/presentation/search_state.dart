import 'package:equatable/equatable.dart';
import '../../home/data/models/lounge_model.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<LoungeModel> lounges;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.lounges = const [],
    this.errorMessage,
  });

  SearchState copyWith({
    SearchStatus? status,
    List<LoungeModel>? lounges,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      lounges: lounges ?? this.lounges,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, lounges, errorMessage];
}
