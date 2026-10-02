import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/exceptions/app_exceptions.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/auth/data/repositories/auth_repository_impl.dart';
import '../../support/mock_auth_remote_source.dart';
import '../../support/mock_auth_local_data_source.dart';

void main() {
  for (final remoteFails in [false, true]) {
    for (final cleanupFails in [false, true]) {
      test(
        'logout remote failure $remoteFails and cleanup failure $cleanupFails',
        () async {
          final remote = MockAuthRemoteSource();
          final local = MockAuthLocalDataSource();
          when(remote.signOut).thenAnswer((_) async {
            if (remoteFails) throw const NetworkException();
          });
          when(local.clearUserData).thenAnswer((_) async {
            if (cleanupFails) throw StateError('synthetic');
          });
          final result = await AuthRepositoryImpl(remote, local).signOut();
          expect(result.isLeft(), remoteFails || cleanupFails);
          if (cleanupFails) {
            expect(
              result.fold((failure) => failure, (_) => null),
              const CacheFailure('auth.cache_cleanup_failed'),
            );
          } else if (remoteFails) {
            expect(
              result.fold((failure) => failure, (_) => null),
              isA<NetworkFailure>(),
            );
          }
          verifyInOrder([remote.signOut, local.clearUserData]);
          verifyNoMoreInteractions(remote);
          verifyNoMoreInteractions(local);
        },
      );
    }
  }
}
