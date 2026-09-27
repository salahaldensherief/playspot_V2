import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/home_params.dart';
import '../../data/models/lounge_model.dart';
import '../repositories/home_repository.dart';

class DiscoverLoungesUseCase {
  final HomeRepository repository;

  DiscoverLoungesUseCase(this.repository);

  Future<Either<Failure, List<LoungeModel>>> call(
    GetLoungesParams params,
  ) {
    return repository.getLounges(params);
  }
}
