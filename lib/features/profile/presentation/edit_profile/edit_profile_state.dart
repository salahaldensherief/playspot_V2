import 'package:equatable/equatable.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';

enum EditProfileStatus { initial, loading, success, error, accountDeleted }

class EditProfileState extends Equatable {
  final EditProfileStatus status;
  final UserModel? user;
  final List<Map<String, dynamic>> cities;
  final String? selectedCityId;
  final String? errorMessage;

  const EditProfileState({
    this.status = EditProfileStatus.initial,
    this.user,
    this.cities = const [],
    this.selectedCityId,
    this.errorMessage,
  });

  EditProfileState copyWith({
    EditProfileStatus? status,
    UserModel? user,
    List<Map<String, dynamic>>? cities,
    String? selectedCityId,
    String? errorMessage,
  }) {
    return EditProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      cities: cities ?? this.cities,
      selectedCityId: selectedCityId ?? this.selectedCityId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, cities, selectedCityId, errorMessage];
}
