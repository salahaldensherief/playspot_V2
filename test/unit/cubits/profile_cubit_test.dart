import 'dart:async';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockPreferenceManager extends Mock implements PreferenceManager {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockProfileRepository mockProfileRepository;
  late MockPreferenceManager mockPreferenceManager;
  late ProfileCubit cubit;

  final testUser = const UserModel(
    id: 'user_123',
    name: 'Test Player',
    email: 'test@playspot.app',
    phone: '01000000000',
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockProfileRepository = MockProfileRepository();
    mockPreferenceManager = MockPreferenceManager();

    when(() => mockProfileRepository.getCurrentUser()).thenReturn(testUser);
    when(() => mockPreferenceManager.getPendingReferralCode()).thenReturn('');

    cubit = ProfileCubit(mockAuthRepository, mockProfileRepository, mockPreferenceManager);
  });

  tearDown(() {
    if (!cubit.isClosed) {
      cubit.close();
    }
  });

  group('Batch 1 — ProfileCubit Unit Tests', () {
    test('history loads next page, deduplicates IDs and stops at the end', () async {
      when(() => mockProfileRepository.getPointsHistory(page: 1)).thenAnswer((_) async =>
        const Right(PaginatedResponse(items: [{'id': 'one'}], totalCount: 40, page: 1, pageSize: 20)));
      when(() => mockProfileRepository.getPointsHistory(page: 2)).thenAnswer((_) async =>
        const Right(PaginatedResponse(items: [{'id': 'one'}, {'id': 'two'}], totalCount: 40, page: 2, pageSize: 20)));
      await cubit.loadPointsHistory(refresh: true);
      await cubit.loadPointsHistory();
      await cubit.loadPointsHistory();
      expect(cubit.state.pointsHistory.map((x) => x['id']), ['one', 'two']);
      expect(cubit.state.hasMorePointsHistory, false);
      verify(() => mockProfileRepository.getPointsHistory(page: 2)).called(1);
    });

    test('failure remains visible and retry repeats the failed page', () async {
      when(() => mockProfileRepository.getPointsHistory(page: 1)).thenAnswer((_) async =>
        const Left(ServerFailure('synthetic failure')));
      await cubit.loadPointsHistory(refresh: true);
      expect(cubit.state.pointsHistoryFailed, true);
      expect(cubit.state.isLoadingMorePointsHistory, false);
      await cubit.loadPointsHistory();
      verify(() => mockProfileRepository.getPointsHistory(page: 1)).called(2);
    });

    test('parallel load-more is suppressed and stale refresh cannot overwrite newer results', () async {
      final pending = Completer<Either<Failure, PaginatedResponse<Map<String, dynamic>>>>();
      var calls = 0;
      when(() => mockProfileRepository.getPointsHistory(page: 1)).thenAnswer((_) {
        calls++;
        if (calls == 1) return pending.future;
        return Future.value(const Right(PaginatedResponse(items: [{'id': 'fresh'}], totalCount: 1, page: 1, pageSize: 20)));
      });
      final first = cubit.loadPointsHistory(refresh: true);
      await cubit.loadPointsHistory();
      expect(calls, 1);
      await cubit.loadPointsHistory(refresh: true);
      pending.complete(const Right(PaginatedResponse(items: [{'id': 'stale'}], totalCount: 1, page: 1, pageSize: 20)));
      await first;
      expect(cubit.state.pointsHistory.single['id'], 'fresh');
    });

    test('initial state is correct', () {
      expect(cubit.state.status, equals(ProfileStatus.initial));
      expect(cubit.state.pointsBalance, equals(0));
    });

    test('redeemPoints prevents duplicate concurrent calls on rapid double-tap', () async {
      when(() => mockProfileRepository.redeemPoints('opt_1'))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return const Right({'success': true, 'new_balance': 150});
          });

      // Rapid double tap
      cubit.redeemPoints('opt_1');
      cubit.redeemPoints('opt_1');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      verify(() => mockProfileRepository.redeemPoints('opt_1')).called(1);
    });

    test('logout prevents duplicate concurrent calls on rapid double-tap', () async {
      when(() => mockAuthRepository.signOut())
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return const Right(null);
          });

      // Rapid double tap
      cubit.logout();
      cubit.logout();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      verify(() => mockAuthRepository.signOut()).called(1);
    });
  });
}
