import 'package:equatable/equatable.dart';
import 'package:playspot/art_core/models/time_range.dart';
import '../data/models/extra_model.dart';
import '../data/models/room_model.dart';

enum LoungeDetailsStatus { initial, loading, success, error }

class LoungeDetailsState extends Equatable {
  final LoungeDetailsStatus status;
  final List<RoomModel> rooms;
  final List<ExtraModel> extras;
  final Map<String, int> selectedExtras;
  final String? selectedRoomId;
  final DateTime? selectedDate;
  final List<String> bookedRoomIds;
  final Map<String, List<TimeRange>> bookedSlotsByRoom;
  final List<String> categories;
  final int availableRoomsCount;
  final String selectedCategory;

  const LoungeDetailsState({
    this.status = LoungeDetailsStatus.initial,
    this.rooms = const [],
    this.extras = const [],
    this.selectedExtras = const {},
    this.selectedRoomId,
    this.selectedDate,
    this.bookedRoomIds = const [],
    this.bookedSlotsByRoom = const {},
    this.categories = const [],
    this.availableRoomsCount = 0,
    this.selectedCategory = '',
  });

  LoungeDetailsState copyWith({
    LoungeDetailsStatus? status,
    List<RoomModel>? rooms,
    List<ExtraModel>? extras,
    Map<String, int>? selectedExtras,
    String? selectedRoomId,
    bool clearRoom = false,
    DateTime? selectedDate,
    List<String>? bookedRoomIds,
    Map<String, List<TimeRange>>? bookedSlotsByRoom,
    List<String>? categories,
    int? availableRoomsCount,
    String? selectedCategory,
  }) {
    return LoungeDetailsState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      extras: extras ?? this.extras,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      selectedRoomId: clearRoom ? null : (selectedRoomId ?? this.selectedRoomId),
      selectedDate: selectedDate ?? this.selectedDate,
      bookedRoomIds: bookedRoomIds ?? this.bookedRoomIds,
      bookedSlotsByRoom: bookedSlotsByRoom ?? this.bookedSlotsByRoom,
      categories: categories ?? this.categories,
      availableRoomsCount: availableRoomsCount ?? this.availableRoomsCount,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  double get totalPrice {
    double basePrice = 0;
    if (selectedRoomId != null) {
      final room = rooms.firstWhere((r) => r.id == selectedRoomId);
      basePrice = room.pricePerHour;
    }
    
    double extrasTotal = 0;
    selectedExtras.forEach((id, qty) {
      final extra = extras.firstWhere((e) => e.id == id);
      extrasTotal += (extra.price * qty);
    });
    
    return basePrice + extrasTotal;
  }

  @override
  List<Object?> get props => [
        status,
        rooms,
        extras,
        selectedExtras,
        selectedRoomId,
        selectedDate,
        bookedRoomIds,
        bookedSlotsByRoom,
        categories,
        availableRoomsCount,
        selectedCategory,
      ];
}
