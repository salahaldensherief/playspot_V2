import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/widgets/buttons/directions_button.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/services/directions_service.dart';
import '../../support/local_translations_loader.dart';
import '../../support/mock_directions_service.dart';

void main() {
  late MockDirectionsService service;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    GetIt.instance.pushNewScope();
    service = MockDirectionsService();
    GetIt.instance.registerSingleton<DirectionsService>(service);
  });
  tearDown(() async {
    await GetIt.instance.popScope();
  });
  Future<void> mount(WidgetTester tester, DirectionsButton button) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: const Locale('ar'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 300, child: button)),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  for (final primary in [true, false]) {
    testWidgets(
      'directions primary=$primary prevents duplicate launch and clears loading',
      (tester) async {
        final pending = Completer<bool>();
        when(
          () => service.openDirections(lat: 0, lng: 0),
        ).thenAnswer((_) => pending.future);
        await mount(
          tester,
          DirectionsButton(
            lat: 0,
            lng: 0,
            isPrimary: primary,
            isFullWidth: true,
          ),
        );
        await tester.tap(find.byType(DirectionsButton));
        await tester.pump();
        await tester.tap(find.byType(DirectionsButton));
        verify(() => service.openDirections(lat: 0, lng: 0)).called(1);
        pending.complete(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'missing coordinates shows an error and never falls back to search',
    (tester) async {
      await mount(tester, const DirectionsButton(lat: 30));
      await tester.tap(find.byType(DirectionsButton));
      await tester.pumpAndSettle();
      expect(find.byType(GameHudToast), findsOneWidget);
      expect(
        tester.widget<GameHudToast>(find.byType(GameHudToast)).message,
        'directions_coordinates_unavailable'.tr(),
      );
      verifyNever(
        () => service.openDirections(
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
