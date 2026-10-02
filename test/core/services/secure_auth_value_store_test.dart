import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/services/secure_auth_value_store.dart';
import '../../support/mock_auth_secure_storage.dart';

void main() {
  late MockAuthSecureStorage storage;
  late SecureAuthValueStore store;
  late Map<String, String> vault;
  String? legacy;
  var removed = 0;
  Future<void> removeLegacy() async {
    removed++;
    legacy = null;
  }

  Future<String?> read() => store.read(
    'session',
    legacyRead: () async => legacy,
    legacyRemove: removeLegacy,
  );

  setUp(() {
    storage = MockAuthSecureStorage();
    vault = {};
    legacy = 'original-session';
    removed = 0;
    store = SecureAuthValueStore(storage: storage, namespace: 'project');
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => vault[call.namedArguments[#key]]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      vault[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((call) async {
      vault.remove(call.namedArguments[#key]);
    });
  });

  test(
    'migration verifies exact stored bytes before removing legacy',
    () async {
      final sequence = <String>[];
      when(() => storage.read(key: 'project:session')).thenAnswer((_) async {
        sequence.add('read');
        return vault['project:session'];
      });
      final result = await store.read(
        'session',
        legacyRead: () async => legacy,
        legacyRemove: () async {
          sequence.add('remove');
          expect(vault['project:session'], legacy);
          await removeLegacy();
        },
      );
      expect(result, 'original-session');
      expect(sequence, ['read', 'read', 'remove']);
      expect(legacy, isNull);
    },
  );

  test('existing secure session wins over stale legacy', () async {
    vault['project:session'] = 'new-session';
    expect(await read(), 'new-session');
    expect(legacy, isNull);
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });

  test('empty stores return no session', () async {
    legacy = null;
    expect(await read(), isNull);
    expect(vault, isEmpty);
  });

  test('secure read failure cannot fall back to plaintext', () async {
    when(
      () => storage.read(key: 'project:session'),
    ).thenThrow(StateError('locked'));
    await expectLater(read(), throwsStateError);
    expect(legacy, 'original-session');
    expect(removed, 0);
  });

  test('write failure preserves legacy for a later retry', () async {
    when(
      () => storage.write(key: 'project:session', value: 'original-session'),
    ).thenThrow(StateError('unavailable'));
    await expectLater(read(), throwsStateError);
    expect(legacy, 'original-session');
    expect(removed, 0);
  });

  test('unverified write preserves legacy and reports failure', () async {
    when(
      () => storage.write(key: 'project:session', value: 'original-session'),
    ).thenAnswer((_) async {});
    await expectLater(read(), throwsStateError);
    expect(legacy, 'original-session');
    expect(removed, 0);
  });

  test('legacy cleanup failure keeps secure copy and can retry', () async {
    await expectLater(
      store.read(
        'session',
        legacyRead: () async => legacy,
        legacyRemove: () async => throw StateError('cleanup'),
      ),
      throwsStateError,
    );
    expect(vault['project:session'], 'original-session');
    expect(legacy, 'original-session');
    expect(await read(), 'original-session');
    expect(legacy, isNull);
  });

  test('a delayed refresh write cannot resurrect a completed logout', () async {
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    when(
      () => storage.write(key: 'project:session', value: 'refreshed'),
    ).thenAnswer((_) async {
      writeStarted.complete();
      await releaseWrite.future;
      vault['project:session'] = 'refreshed';
    });
    final refresh = store.write(
      'session',
      'refreshed',
      legacyRemove: removeLegacy,
    );
    await writeStarted.future;
    var logoutFinished = false;
    final logout = store
        .remove('session', legacyRemove: removeLegacy)
        .then((_) => logoutFinished = true);
    await Future<void>.delayed(Duration.zero);
    expect(logoutFinished, isFalse);
    releaseWrite.complete();
    await refresh;
    await logout;
    expect(vault, isEmpty);
    expect(legacy, isNull);
  });

  test('failed operation does not poison following logout', () async {
    when(
      () => storage.write(key: 'project:session', value: 'bad'),
    ).thenThrow(StateError('failure'));
    await expectLater(
      store.write('session', 'bad', legacyRemove: removeLegacy),
      throwsStateError,
    );
    await store.remove('session', legacyRemove: removeLegacy);
    expect(vault, isEmpty);
    expect(legacy, isNull);
  });

  test(
    'logout deletes only this scoped session and retires legacy first',
    () async {
      vault.addAll({
        'project:session': 'active',
        'hive-key': 'keep',
        'other:session': 'keep',
      });
      when(() => storage.delete(key: 'project:session')).thenAnswer((_) async {
        expect(legacy, isNull);
        vault.remove('project:session');
      });
      await store.remove('session', legacyRemove: removeLegacy);
      expect(vault, {'hive-key': 'keep', 'other:session': 'keep'});
    },
  );
}
