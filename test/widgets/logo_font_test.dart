import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/logo/logo_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/local_translations_loader.dart';

void main() {
  testWidgets('splash wordmark keeps Orbitron in Arabic', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('ar'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const Scaffold(body: Center(child: LogoWidget())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final wordmarkPart in ['PlaySp', 't']) {
      final text = tester.widget<Text>(find.text(wordmarkPart));
      expect(text.style?.fontFamily, 'Orbitron');
      expect(text.style?.fontWeight, FontWeight.w400);
    }
  });
}
