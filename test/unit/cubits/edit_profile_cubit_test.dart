import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/data/models/profile_params.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/edit_profile/edit_profile_cubit.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockProfileRepository mockProfileRepository;
  late MockAuthRepository mockAuthRepository;
  late EditProfileCubit cubit;

  final testUser = const UserModel(
    id: 'user_123',
    name: 'Original Name',
    phone: '01000000000',
    email: 'test@playspot.app',
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(UpdateProfileParams(name: '', phone: ''));
  });

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockAuthRepository = MockAuthRepository();

    when(() => mockProfileRepository.getCurrentUser()).thenReturn(testUser);

    cubit = EditProfileCubit(mockProfileRepository, mockAuthRepository);
  });

  tearDown(() {
    if (!cubit.isClosed) {
      cubit.close();
    }
  });

  group('Batch 3 — EditProfileCubit Unit Tests', () {
    test('init populates text controllers with current user data', () async {
      when(() => mockProfileRepository.getUserProfile())
          .thenAnswer((_) async => Right(testUser));

      await cubit.init(isArabic: false);

      expect(cubit.nameController.text, equals('Original Name'));
      expect(cubit.phoneController.text, equals('01000000000'));
      expect(cubit.emailController.text, equals('test@playspot.app'));
    });

    test('updateProfile prevents duplicate calls when already loading', () async {
      when(() => mockProfileRepository.updateProfile(any()))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return Right(testUser.copyWith(name: 'New Name'));
          });

      cubit.nameController.text = 'New Name';
      cubit.phoneController.text = '01000000000';

      cubit.updateProfile();
      cubit.updateProfile(); // duplicate invocation

      await Future<void>.delayed(const Duration(milliseconds: 150));
      verify(() => mockProfileRepository.updateProfile(any())).called(1);
    });
  });
}
