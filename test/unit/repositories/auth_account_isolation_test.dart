import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/auth/data/datasources/local/auth_local_data_source.dart';
import 'package:playspot/features/auth/data/datasources/remote/auth_remote_data_source.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/auth/data/repositories/auth_repository_impl.dart';

class _Remote extends Mock implements AuthRemoteSource {}
class _Local extends Mock implements AuthLocalDataSource {}

void main() {
  setUpAll(() => registerFallbackValue(const UserModel(id: 'fallback')));
  late _Remote remote;
  late _Local local;
  late AuthRepositoryImpl repository;
  setUp(() {
    remote = _Remote();
    local = _Local();
    repository = AuthRepositoryImpl(remote, local);
    when(() => local.saveUserData(any())).thenAnswer((_) async {});
  });

  test('new account never inherits the previous account phone', () {
    when(() => remote.getCurrentUser()).thenReturn(const UserModel(id: 'new'));
    when(() => local.getCachedUser()).thenReturn(
      const UserModel(id: 'previous', phone: '01000000000'),
    );
    final user = repository.getCurrentUser();
    expect(user?.id, 'new');
    expect(user?.phone, isNull);
    final saved = verify(() => local.saveUserData(captureAny())).captured.single as UserModel;
    expect(saved.id, 'new');
    expect(saved.phone, isNull);
  });

  test('same account can retain its cached phone', () {
    when(() => remote.getCurrentUser()).thenReturn(const UserModel(id: 'same'));
    when(() => local.getCachedUser()).thenReturn(
      const UserModel(id: 'same', phone: '01000000000'),
    );
    expect(repository.getCurrentUser()?.phone, '01000000000');
  });

  test('cached account cannot restore an absent session', () {
    when(() => remote.getCurrentUser()).thenReturn(null);
    expect(repository.getCurrentUser(), isNull);
    verifyNever(() => local.getCachedUser());
  });

  test('profile copy retains and updates the ban explanation', () {
    const user = UserModel(id: 'same', isBanned: true, bannedReason: 'existing');
    expect(user.copyWith(phone: '01000000000').bannedReason, 'existing');
    expect(user.copyWith(bannedReason: 'updated').bannedReason, 'updated');
  });
  test('session metadata cannot assign an application role or ban state', () {
    final user = UserModel.fromSupabaseUser({
      'id': 'current',
      'user_metadata': {'role': 'super_admin', 'is_banned': true},
    });
    expect(user.role, 'user');
    expect(user.isBanned, false);
  });

  test('session metadata does not erase a cached database ban', () {
    when(() => remote.getCurrentUser()).thenReturn(const UserModel(id: 'same'));
    when(() => local.getCachedUser()).thenReturn(
      const UserModel(id: 'same', role: 'user', isBanned: true, bannedReason: 'server reason'));
    final user = repository.getCurrentUser();
    expect(user?.isBanned, true);
    expect(user?.bannedReason, 'server reason');
  });

}
