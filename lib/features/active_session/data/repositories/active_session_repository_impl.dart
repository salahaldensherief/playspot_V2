import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../core/datasources/local/app_cache_local_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/out_of_stock_item.dart';
import '../../domain/entities/upsell_suggestion.dart';
import '../../domain/repositories/active_session_repository.dart';
import '../datasources/remote/active_session_remote_data_source.dart';
import '../models/canteen_menu_data_model.dart';
import '../models/order_item_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';

class ActiveSessionRepositoryImpl with RepositoryHelper implements ActiveSessionRepository {
  final ActiveSessionRemoteDataSource _remoteDataSource;
  final AppCacheLocalDataSource _cacheLocalDataSource;

  ActiveSessionRepositoryImpl(
    this._remoteDataSource,
    this._cacheLocalDataSource,
  );

  @override
  Future<Either<Failure, ActiveSession?>> getActiveSession({String? bookingId}) async {
    return await callRepository(() => _remoteDataSource.getActiveSession(bookingId: bookingId));
  }

  @override
  Stream<ActiveSession> streamActiveSession(String bookingId) {
    return _remoteDataSource.streamActiveSession(bookingId);
  }

  @override
  Stream<ActiveSession?> watchUserActiveSession() {
    return _remoteDataSource.watchUserActiveSession();
  }

  @override
  Future<Either<Failure, void>> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    return await callRepository(() => _remoteDataSource.extendTime(bookingId, additionalMinutes, additionalCost));
  }

  @override
  Future<Either<Failure, void>> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    return await callRepository(() => _remoteDataSource.requestExtension(
          bookingId: bookingId,
          requestedMinutes: requestedMinutes,
        ));
  }

  @override
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItem> items) async {
    try {
      final modelItems = items.map((i) => i is OrderItemModel ? i : OrderItemModel.fromEntity(i)).toList();
      await _remoteDataSource.placeOrder(bookingId, modelItems);
      return const Right(null);
    } on PostgrestException catch (e) {
      if (e.message.contains('OUT_OF_STOCK')) {
        List<OutOfStockItem> unavailable = [];
        try {
          if (e.details != null) {
            final dynamic detailsJson = e.details is String ? jsonDecode(e.details as String) : e.details;
            if (detailsJson is Map && detailsJson['unavailable_items'] is List) {
              unavailable = (detailsJson['unavailable_items'] as List)
                  .map((item) => OutOfStockItem.fromJson(Map<String, dynamic>.from(item as Map)))
                  .toList();
            }
          }
        } catch (_) {}
        return Left(CanteenOutOfStockFailure(
          message: AppStrings.outOfStockError.tr(),
          unavailableItems: unavailable,
        ));
      }
      return Left(ServerFailure("${e.code}: ${e.message}"));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CanteenMenuData>> getCanteenMenu(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getCanteenMenu(loungeId));
  }

  @override
  Future<Either<Failure, List<UpsellSuggestion>>> getUpsellSuggestions(String bookingId) async {
    return await callRepository(() => _remoteDataSource.getUpsellSuggestions(bookingId));
  }

  @override
  Future<Either<Failure, void>> recordUpsellEvent({
    required String ruleId,
    required String bookingId,
    required String event,
    String? canteenOrderId,
    double? amount,
  }) async {
    return await callRepository(() => _remoteDataSource.recordUpsellEvent(
          ruleId: ruleId,
          bookingId: bookingId,
          event: event,
          canteenOrderId: canteenOrderId,
          amount: amount,
        ));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to update cache
        _remoteDataSource.getLoungeMenu(loungeId).then((menu) {
          if (menu.isNotEmpty) {
            _cacheLocalDataSource.cacheLoungeMenu(loungeId, menu);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getLoungeMenu(loungeId));

    result.fold(
      (_) {
        final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
        if (cached != null && cached.isNotEmpty) {
          return Right(cached);
        }
      },
      (menu) {
        if (menu.isNotEmpty) {
          _cacheLocalDataSource.cacheLoungeMenu(loungeId, menu);
        }
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, void>> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  }) async {
    return await callRepository(() => _remoteDataSource.requestStaffAssistance(
      bookingId: bookingId,
      callType: callType,
      notes: notes,
    ));
  }

  @override
  Future<Either<Failure, void>> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    return await callRepository(() => _remoteDataSource.submitLoungeReview(
      loungeId: loungeId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    ));
  }

  @override
  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getActiveLoungeRequestsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return await callRepository(
      () => _remoteDataSource.getActiveLoungeRequestsPage(loungeId: loungeId, page: page, pageSize: pageSize),
    );
  }
}
