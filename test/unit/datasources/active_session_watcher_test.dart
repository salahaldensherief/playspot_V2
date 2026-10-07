import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/active_session/data/datasources/remote/active_session_watcher.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Client extends Mock implements SupabaseClient {}
class _Auth extends Mock implements GoTrueClient {}
class _Channel extends Mock implements RealtimeChannel {}

void main() {
  setUpAll(() {
    registerFallbackValue(PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: 'fixture',
    ));
    registerFallbackValue((PostgresChangePayload _) {});
    registerFallbackValue(_Channel());
  });

  test('cancelled watcher never opens channels from a late session response', () async {
    final client = _Client();
    final auth = _Auth();
    final channel = _Channel();
    final authEvents = StreamController<AuthState>(sync: true);
    final result = Completer<ActiveSessionModel?>();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(User(
      id: 'fixture-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ));
    when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents.stream);
    when(() => client.channel(any())).thenReturn(channel);
    when(() => client.removeChannel(any())).thenAnswer((_) async => 'ok');
    when(() => channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: any(named: 'table'),
      filter: any(named: 'filter'),
      callback: any(named: 'callback'),
    )).thenReturn(channel);
    when(() => channel.subscribe()).thenReturn(channel);
    var fetches = 0;
    final received = <ActiveSessionModel?>[];
    final watcher = ActiveSessionWatcher(client, fetch: () {
      fetches++;
      return result.future;
    });
    expect(authEvents.hasListener, isFalse);
    final subscription = watcher.stream.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 1);
    await subscription.cancel();
    result.complete(ActiveSessionModel(
      bookingId: 'fixture-booking',
      loungeId: 'fixture-lounge',
      loungeName: '',
      roomName: '',
      deviceName: '',
      startTime: DateTime(2026),
      endTime: DateTime(2026, 1, 1, 1),
      basePrice: 0,
      status: 'in_progress',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    expect(authEvents.hasListener, isFalse);
    verify(() => client.channel(any())).called(1);
    verify(() => client.removeChannel(channel)).called(1);
    await authEvents.close();
  });
}
