import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/order_item.dart';
import '../repositories/active_session_repository.dart';

class PlaceSessionOrderUseCase {
  final ActiveSessionRepository repository;

  PlaceSessionOrderUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required List<OrderItem> items,
  }) {
    return repository.placeOrder(bookingId, items);
  }
}
