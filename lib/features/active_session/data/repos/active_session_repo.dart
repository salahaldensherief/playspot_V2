import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/active_session_remote_data_source.dart';
import '../models/active_session_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';

abstract class ActiveSessionRepository {
  Future<Either<Failure, ActiveSessionModel?>> getActiveSession();
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Future<Either<Failure, void>> extendTime(String bookingId, DateTime newEndTime, double additionalCost);
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItemModel> items);
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(String loungeId);
}

class ActiveSessionRepositoryImpl with RepositoryHelper implements ActiveSessionRepository {
  final ActiveSessionRemoteDataSource _remoteDataSource;

  ActiveSessionRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ActiveSessionModel?>> getActiveSession() async {
    return await callRepository(() => _remoteDataSource.getActiveSession());
  }

  @override
  Stream<ActiveSessionModel> streamActiveSession(String bookingId) {
    return _remoteDataSource.streamActiveSession(bookingId);
  }

  @override
  Future<Either<Failure, void>> extendTime(String bookingId, DateTime newEndTime, double additionalCost) async {
    return await callRepository(() => _remoteDataSource.extendTime(bookingId, newEndTime, additionalCost));
  }

  @override
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItemModel> items) async {
    return await callRepository(() => _remoteDataSource.placeOrder(bookingId, items));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getLoungeMenu(loungeId));
  }
}
