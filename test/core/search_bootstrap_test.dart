import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/di.dart' as di;
import 'package:playspot/features/home/data/models/home_params.dart';
import 'package:playspot/features/home/domain/usecases/discover_lounges_usecase.dart';
import 'package:playspot/features/search/presentation/search_cubit.dart';
import 'package:playspot/features/search/presentation/search_state.dart';

import '../support/mock_discover_lounges_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory cacheDirectory;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp('playspot-search-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => cacheDirectory.path);
    await di.sl.reset();
  });

  tearDown(() async {
    await di.sl.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    // GetStorage keeps its file lock until process exit on Windows. This
    // process-only temp cache avoids touching the application's real storage.
  });

  test('normal bootstrap provides independent search controllers', () async {
    await di.init();
    expect(di.sl.isRegistered<SearchCubit>(), isTrue);

    final discovery = MockDiscoverLoungesUseCase();
    await di.sl.unregister<DiscoverLoungesUseCase>();
    di.sl.registerSingleton<DiscoverLoungesUseCase>(discovery);
    when(() => discovery(any())).thenAnswer((_) async => const Right([]));

    final first = di.sl<SearchCubit>();
    final second = di.sl<SearchCubit>();
    expect(identical(first, second), isFalse);
    await first.search(query: 'Orbit');
    expect(first.state.status, SearchStatus.success);
    expect(second.state.status, isNot(SearchStatus.loading));
    final params =
        verify(() => discovery(captureAny())).captured.single
            as GetLoungesParams;
    expect(params.searchQuery, 'Orbit');
    await first.close();
    await second.close();
  });

  setUpAll(() => registerFallbackValue(GetLoungesParams()));
}
