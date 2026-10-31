import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/widgets/notifications/network_status_banner.dart';
import 'package:playspot/core/services/network_connectivity_service.dart';
import '../support/local_translations_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar']) {
    testWidgets(
      'offline and restored banners keep header tappable in $language',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final connectivity = NetworkConnectivityService().isConnectedNotifier;
        connectivity.value = false;
        addTearDown(() => connectivity.value = true);
        var taps = 0;
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, _) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: NetworkStatusWrapper(
                    child: Scaffold(
                      appBar: AppBar(
                        title: TextButton(
                          onPressed: () => taps++,
                          child: const Text('Header action'),
                        ),
                      ),
                      body: const Text('Page content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Header action'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
        // Reconnect after a real offline event: the transient banner must also
        // reserve space and restore normal page constraints when it expires.
        connectivity.value = true;
        await tester.pump();
        connectivity.value = false;
        await tester.pump();
        connectivity.value = true;
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('Header action'));
        expect(taps, 2);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Header action'));
        expect(taps, 3);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
