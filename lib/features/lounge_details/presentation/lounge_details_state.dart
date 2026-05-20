import 'package:equatable/equatable.dart';

import '../data/extra_model.dart';
import '../data/room_model.dart';

enum LoungeDetailsStatus { initial, loading, success, error }

class LoungeDetailsState extends Equatable {
  final LoungeDetailsStatus status;
  final List<RoomModel> rooms;
  final List<ExtraModel> extras;
  final Map<String, int> selectedExtras; // id -> quantity

  const LoungeDetailsState({
    this.status = LoungeDetailsStatus.initial,
    this.rooms = const [],
    this.extras = const [],
    this.selectedExtras = const {},
  });

  LoungeDetailsState copyWith({
    LoungeDetailsStatus? status,
    List<RoomModel>? rooms,
    List<ExtraModel>? extras,
    Map<String, int>? selectedExtras,
  }) {
    return LoungeDetailsState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      extras: extras ?? this.extras,
      selectedExtras: selectedExtras ?? this.selectedExtras,
    );
  }

  @override
  List<Object?> get props => [status, rooms, extras, selectedExtras];
}
