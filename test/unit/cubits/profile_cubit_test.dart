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
