import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/canteen_menu_data_model.dart';
import '../repositories/active_session_repository.dart';

class GetCanteenMenuUseCase {
  final ActiveSessionRepository repository;

  GetCanteenMenuUseCase(this.repository);

  Future<Either<Failure, CanteenMenuData>> call({required String loungeId}) {
    return repository.getCanteenMenu(loungeId);
  }
}
