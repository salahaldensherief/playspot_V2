import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/datasources/local/app_cache_local_data_source.dart';
import 'package:playspot/features/active_session/data/datasources/remote/active_session_remote_data_source.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';
import 'package:playspot/features/active_session/data/models/order_item_model.dart';
import 'package:playspot/features/active_session/data/repositories/active_session_repository_impl.dart';

class MockActiveSessionRemoteDataSource extends Mock
    implements ActiveSessionRemoteDataSource {}

class MockAppCacheLocalDataSource extends Mock
    implements AppCacheLocalDataSource {}

void main() {
  late MockActiveSessionRemoteDataSource mockRemoteDataSource;
  late MockAppCacheLocalDataSource mockCacheLocalDataSource;
  late ActiveSessionRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockActiveSessionRemoteDataSource();
    mockCacheLocalDataSource = MockAppCacheLocalDataSource();
    repository = ActiveSessionRepositoryImpl(mockRemoteDataSource, mockCacheLocalDataSource);
  });

  final testSession = ActiveSessionModel(
    bookingId: 'b_123',
    loungeId: 'l_456',
    loungeName: 'Gamed Lounge',
    roomName: 'VIP Room',
    deviceName: 'PS5',
    startTime: DateTime.now().subtract(const Duration(minutes: 10)),
    endTime: DateTime.now().add(const Duration(minutes: 50)),
    basePrice: 100.0,
    status: 'in_progress',
  );

  group('ActiveSessionRepository Unit Tests', () {
    test('getActiveSession returns Right(ActiveSessionModel) on success', () async {
      when(() => mockRemoteDataSource.getActiveSession(bookingId: 'b_123'))
          .thenAnswer((_) async => testSession);

      final result = await repository.getActiveSession(bookingId: 'b_123');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should have returned Right'),
        (session) => expect(session?.bookingId, 'b_123'),
      );
      verify(() => mockRemoteDataSource.getActiveSession(bookingId: 'b_123')).called(1);
    });

    test('requestExtension calls remoteDataSource.requestExtension and returns Right(void)', () async {
      when(() => mockRemoteDataSource.requestExtension(
            bookingId: 'b_123',
            requestedMinutes: 30,
          )).thenAnswer((_) async => {});

      final result = await repository.requestExtension(
        bookingId: 'b_123',
        requestedMinutes: 30,
      );

      expect(result.isRight(), isTrue);
      verify(() => mockRemoteDataSource.requestExtension(
            bookingId: 'b_123',
            requestedMinutes: 30,
          )).called(1);
    });

    test('placeOrder calls remoteDataSource.placeOrder and returns Right(void)', () async {
      final items = [
        const OrderItemModel(id: '1', name: 'Water', price: 10.0, quantity: 2)
      ];

      when(() => mockRemoteDataSource.placeOrder('b_123', items))
          .thenAnswer((_) async => {});

      final result = await repository.placeOrder('b_123', items);

      expect(result.isRight(), isTrue);
      verify(() => mockRemoteDataSource.placeOrder('b_123', items)).called(1);
    });
  });
}
