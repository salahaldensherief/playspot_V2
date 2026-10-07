import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/auth/data/datasources/remote/auth_remote_data_source.dart';
import 'package:playspot/features/auth/domain/strategies/auth_context.dart';
import 'package:playspot/core/services/social_auth_service.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';

class _Client extends Mock implements SupabaseClient {}
class _Functions extends Mock implements FunctionsClient {}
class _Storage extends Mock implements StorageService {}
class _Social extends Mock implements SocialAuthService {}
class _Context extends Mock implements AuthContext {}

void main() {
  for (final response in [
    FunctionResponse(status: 200, data: {'success': false}),
    FunctionResponse(status: 200, data: null),
    FunctionResponse(status: 500, data: {'success': true}),
  ]) {
    test('unconfirmed account deletion never invokes legacy destructive fallback', () async {
      final client = _Client(), functions = _Functions();
      when(() => client.functions).thenReturn(functions);
      when(() => functions.invoke('delete-account')).thenAnswer((_) async => response);
      final source = AuthRemoteSourceImpl(client, _Storage(), _Social(), _Context());
      await expectLater(source.deleteAccount(), throwsA(isA<Exception>()));
      verify(() => functions.invoke('delete-account')).called(1);
      verifyNever(() => client.rpc('delete_user_account'));
    });
  }
  test('network failure never retries through destructive database deletion', () async {
    final client = _Client(), functions = _Functions();
    when(() => client.functions).thenReturn(functions);
    when(() => functions.invoke('delete-account')).thenThrow(Exception('synthetic network failure'));
    final source = AuthRemoteSourceImpl(client, _Storage(), _Social(), _Context());
    await expectLater(source.deleteAccount(), throwsA(isA<Exception>()));
    verifyNever(() => client.rpc('delete_user_account'));
  });
}
