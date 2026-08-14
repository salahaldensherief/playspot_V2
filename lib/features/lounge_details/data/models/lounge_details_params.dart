import '../../../home/data/models/category_model.dart';
import '../../../home/data/models/lounge_model.dart';
import 'extra_model.dart';
import 'room_model.dart';
import 'review_model.dart';

/// Parameters for updating booking availability and lounge data in UI
class UpdateBookingsParams {
  final String loungeId;
  final DateTime date;
  final List<RoomModel> rooms;
  final List<ExtraModel> extras;
  final LoungeModel lounge;
  final List<CategoryModel>? deviceCategories;
  final List<ReviewModel>? reviews;

  UpdateBookingsParams({
    required this.loungeId,
    required this.date,
    required this.rooms,
    required this.extras,
    required this.lounge,
    this.deviceCategories,
    this.reviews,
  });
}
