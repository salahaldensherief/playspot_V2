import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/entities/order_item.dart';
import 'package:playspot/features/active_session/domain/repositories/active_session_repository.dart';
import 'package:playspot/features/active_session/domain/usecases/extend_session_time_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/get_active_session_usecase.dart';
import 'package:playspot/features/active_session/domain/usecases/place_session_order_usecase.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';

class FakeActiveSessionRepository implements ActiveSessionRepository {
  ActiveSession? mockSession;
  Failure? mockFailure;

  @override
  Future<Either<Failure, ActiveSession?>> getActiveSession({String? bookingId}) async {
    if (mockFailure != null) return Left(mockFailure!);
    return Right(mockSession);
  }

  @override
  Stream<ActiveSession> streamActiveSession(String bookingId) {
    if (mockSession != null) return Stream.value(mockSession!);
    return const Stream.empty();
  }

  @override
  Stream<ActiveSession?> watchUserActiveSession() {
    return Stream.value(mockSession);
  }

  @override
  Future<Either<Failure, void>> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    if (mockFailure != null) return Left(mockFailure!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> requestExtension({required String bookingId, required int requestedMinutes}) async {
    if (mockFailure != null) return Left(mockFailure!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItem> items) async {
    if (mockFailure != null) return Left(mockFailure!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(String loungeId, {bool forceRefresh = false}) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, void>> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getActiveLoungeRequestsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return Right(PaginatedResponse(items: [], totalCount: 0, page: page, pageSize: pageSize));
  }
}

void main() {
  group('ActiveSession Entity & UseCases Unit Tests', () {
    late FakeActiveSessionRepository repository;
    late GetActiveSessionUseCase getActiveSessionUseCase;
    late ExtendSessionTimeUseCase extendSessionTimeUseCase;
    late PlaceSessionOrderUseCase placeSessionOrderUseCase;

    final now = DateTime.now();
    final testSession = ActiveSession(
      bookingId: 'booking_1',
      loungeId: 'lounge_1',
      loungeName: 'Apex Lounge',
      roomName: 'VIP 1',
      deviceName: 'PS5 Pro',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 1)),
      basePrice: 100.0,
      extensionsPrice: 25.0,
      orders: const [
        OrderItem(id: '1', name: 'Pepsi', price: 20.0, quantity: 2),
        OrderItem(id: '2', name: 'Chips', price: 15.0, quantity: 1, totalPriceOverride: 12.0),
      ],
      status: 'in_progress',
      extensionStatus: 'pending',
      requestedExtensionMinutes: 30,
    );

    setUp(() {
      repository = FakeActiveSessionRepository();
      getActiveSessionUseCase = GetActiveSessionUseCase(repository);
      extendSessionTimeUseCase = ExtendSessionTimeUseCase(repository);
      placeSessionOrderUseCase = PlaceSessionOrderUseCase(repository);
    });

    test('OrderItem calculations should respect totalPriceOverride', () {
      final itemNormal = const OrderItem(id: '1', name: 'Water', price: 10.0, quantity: 3);
      expect(itemNormal.total, 30.0);

      final itemOverride = const OrderItem(
        id: '2',
        name: 'Promo Drink',
        price: 25.0,
        quantity: 2,
        totalPriceOverride: 40.0,
      );
      expect(itemOverride.total, 40.0);
    });

    test('ActiveSession calculations should be accurate', () {
      expect(testSession.ordersTotal, 40.0 + 12.0); // 52.0
      expect(testSession.grandTotal, 100.0 + 25.0 + 52.0); // 177.0
      expect(testSession.isExtensionPending, isTrue);
      expect(testSession.isExtensionRejected, isFalse);
      expect(testSession.hasStarted, isTrue);
      expect(testSession.isUpcoming, isFalse);
      expect(testSession.totalPlayDurationMinutes, 120);
      expect(testSession.formattedPlayDuration, '2 h');

      final cost30 = testSession.calculateExtensionCost(30);
      expect(cost30, greaterThan(0.0));
    });

    test('GetActiveSessionUseCase should return session on success', () async {
      repository.mockSession = testSession;

      final result = await getActiveSessionUseCase(bookingId: 'booking_1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not fail'),
        (session) => expect(session?.bookingId, 'booking_1'),
      );
    });

    test('ExtendSessionTimeUseCase should return success', () async {
      final result = await extendSessionTimeUseCase(
        bookingId: 'booking_1',
        additionalMinutes: 30,
        additionalCost: 25.0,
      );

      expect(result.isRight(), isTrue);
    });

    test('PlaceSessionOrderUseCase should return success', () async {
      final result = await placeSessionOrderUseCase(
        bookingId: 'booking_1',
        items: [const OrderItem(id: '1', name: 'Cola', price: 15.0, quantity: 1)],
      );

      expect(result.isRight(), isTrue);
    });
  });
}
