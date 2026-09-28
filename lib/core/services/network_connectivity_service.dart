import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(true);

  void initialize() {
    _subscription?.cancel();
    _checkInitialConnectivity();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      isConnectedNotifier.value = !isOffline;
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      isConnectedNotifier.value = !isOffline;
    } catch (_) {
      isConnectedNotifier.value = true;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
