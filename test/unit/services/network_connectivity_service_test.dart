import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/services/network_connectivity_service.dart';

class _Connectivity extends Mock implements Connectivity {}

void main() {
  test('late initial result cannot overwrite a newer connectivity event', () async {
    final connectivity = _Connectivity();
    final initial = Completer<List<ConnectivityResult>>();
    final events = StreamController<List<ConnectivityResult>>(sync: true);
    when(() => connectivity.checkConnectivity()).thenAnswer((_) => initial.future);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => events.stream);
    final service = NetworkConnectivityService.withConnectivity(connectivity);
    service.initialize();
    service.initialize();
    events.add([ConnectivityResult.none]);
    expect(service.isConnectedNotifier.value, isFalse);
    initial.complete([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(service.isConnectedNotifier.value, isFalse);
    verify(() => connectivity.checkConnectivity()).called(1);
    service.dispose();
    await events.close();
    service.isConnectedNotifier.dispose();
  });

  test('dispose invalidates an initial check still in flight', () async {
    final connectivity = _Connectivity();
    final initial = Completer<List<ConnectivityResult>>();
    final events = StreamController<List<ConnectivityResult>>();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) => initial.future);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => events.stream);
    final service = NetworkConnectivityService.withConnectivity(connectivity);
    service.initialize();
    service.dispose();
    initial.complete([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(service.isConnectedNotifier.value, isTrue);
    await events.close();
    service.isConnectedNotifier.dispose();
  });
}
