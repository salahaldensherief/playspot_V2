import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal() : _connectivity = Connectivity();
  NetworkConnectivityService.withConnectivity(this._connectivity);

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _revision = 0;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(true);

  void initialize() {
    if (_subscription != null) return;
    final revision = ++_revision;
    _checkInitialConnectivity(revision);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _revision++;
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      isConnectedNotifier.value = !isOffline;
    });
  }

  Future<void> _checkInitialConnectivity(int revision) async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (revision != _revision) return;
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      isConnectedNotifier.value = !isOffline;
    } catch (_) {
      if (revision != _revision) return;
      isConnectedNotifier.value = true;
    }
  }

  void dispose() {
    _revision++;
    _subscription?.cancel();
    _subscription = null;
  }
}
