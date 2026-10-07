import 'dart:async';
import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/active_session_model.dart';

class ActiveSessionWatcher {
  final SupabaseClient _client;
  final Future<ActiveSessionModel?> Function() _fetch;
  late final StreamController<ActiveSessionModel?> _controller;
  StreamSubscription<AuthState>? _auth;
  RealtimeChannel? _userChannel;
  RealtimeChannel? _bookingChannel;
  Future<void> _queue = Future<void>.value();
  String? _userId;
  String? _bookingId;
  int _generation = 0;
  bool _closed = false;
  bool _refreshQueued = false;
  static int _nextId = 0;
  final int _id = _nextId++;

  ActiveSessionWatcher(
    this._client, {
    required Future<ActiveSessionModel?> Function() fetch,
  }) : _fetch = fetch {
    _controller = StreamController<ActiveSessionModel?>.broadcast(
      onListen: _start,
      onCancel: () => unawaited(_stop()),
    );
  }

  Stream<ActiveSessionModel?> get stream => _controller.stream;

  bool _current(int generation) => !_closed && generation == _generation;

  void _start() {
    _auth = _client.auth.onAuthStateChange.listen((state) {
      _bind(state.session?.user.id);
    });
    _bind(_client.auth.currentUser?.id);
  }

  void _enqueue(Future<void> Function() work) {
    _queue = _queue
        .then((_) async {
          if (!_closed) await work();
        })
        .catchError((Object error, StackTrace stack) {
          dev.log(
            '[LIVESESSION_DS] Session watcher error',
            error: error,
            stackTrace: stack,
          );
        });
  }

  void _bind(String? userId) {
    if (_closed) return;
    if (_userId == userId && _generation > 0) {
      _refresh(_generation);
      return;
    }
    _userId = userId;
    final generation = ++_generation;
    if (userId == null) _controller.add(null);
    _enqueue(() async {
      if (!_current(generation)) return;
      await _clearChannels();
      if (!_current(generation)) return;
      if (userId == null) {
        return;
      }
      _userChannel = _client.channel('user_sessions_${_id}_$userId');
      _userChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => _refresh(generation),
          )
          .subscribe();
      await _sync(generation);
    });
  }

  void _refresh(int generation) {
    if (!_current(generation) || _refreshQueued || _userId == null) return;
    _refreshQueued = true;
    _enqueue(() async {
      _refreshQueued = false;
      if (_current(generation)) await _sync(generation);
    });
  }

  Future<void> _sync(int generation) async {
    final session = await _fetch();
    if (!_current(generation)) return;
    _controller.add(session);
    if (session?.bookingId == _bookingId) return;
    final previous = _bookingChannel;
    _bookingChannel = null;
    _bookingId = null;
    if (previous != null) await _client.removeChannel(previous);
    if (!_current(generation) || session == null) return;
    _bookingId = session.bookingId;
    _bookingChannel = _client.channel('session_${_id}_${session.bookingId}');
    _bookingChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: session.bookingId,
          ),
          callback: (_) => _refresh(generation),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'canteen_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: session.bookingId,
          ),
          callback: (_) => _refresh(generation),
        )
        .subscribe();
  }

  Future<void> _clearChannels() async {
    final channels = [
      _bookingChannel,
      _userChannel,
    ].whereType<RealtimeChannel>().toList();
    _bookingChannel = null;
    _userChannel = null;
    _bookingId = null;
    await Future.wait(channels.map(_client.removeChannel));
  }

  Future<void> _stop() async {
    _closed = true;
    _generation++;
    await _auth?.cancel();
    _auth = null;
    try {
      await _clearChannels();
    } catch (error, stack) {
      dev.log(
        '[LIVESESSION_DS] Session cleanup error',
        error: error,
        stackTrace: stack,
      );
    } finally {
      unawaited(_controller.close());
    }
  }
}
