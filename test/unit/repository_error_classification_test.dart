import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/core/utils/repository_helper.dart';
import 'package:playspot/core/error/failures.dart';

class TestRepository with RepositoryHelper {}
void main() {
  test('expired JWT is identified as a session error, not missing permissions', () async {
    final result = await TestRepository().callRepository<int>(() async =>
      throw PostgrestException(message: 'JWT expired', code: 'PGRST301'));
    final failure = result.fold((failure) => failure, (_) => throw StateError('Expected failure'));
    expect(failure, isA<AuthFailure>());
    expect(failure.message, contains('الجلسة'));
    expect(failure.message, isNot(contains('ليس لديك صلاحية')));
  });
  test('RLS denial stays a permission error and does not request login', () async {
    final result = await TestRepository().callRepository<int>(() async =>
      throw PostgrestException(message: 'new row violates row-level security policy', code: '42501'));
    final failure = result.fold((failure) => failure, (_) => throw StateError('Expected failure'));
    expect(failure.message, contains('صلاح'));
    expect(failure.message, isNot(contains('تسجيل الدخول')));
  });
}
