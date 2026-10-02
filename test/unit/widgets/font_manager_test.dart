import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/widgets/text/font_manager.dart';
import '../../support/local_translations_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final language in ['ar', 'en']) {
    testWidgets('explicit button style size is respected in $language', (
      tester,
    ) async {
      TextStyle? inherited;
      TextStyle? overridden;
      await tester.pumpWidget(
        EasyLocalization(
          key: ValueKey(language),
          supportedLocales: const [Locale('ar'), Locale('en')],
          startLocale: Locale(language),
          saveLocale: false,
          path: 'assets/lang',
          assetLoader: const LocalTranslationsLoader(),
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              home: Builder(
                builder: (context) {
                  inherited = FontsManager.getStyle(
                    context: context,
                    baseStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                  overridden = FontsManager.getStyle(
                    context: context,
                    fontSize: 12,
                    baseStyle: const TextStyle(fontSize: 18),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      final factor = language == 'ar' ? 1.12 : 1.0;
      expect(inherited?.fontSize, closeTo(18 * factor, 0.001));
      expect(overridden?.fontSize, closeTo(12 * factor, 0.001));
      expect(inherited?.fontWeight, FontWeight.bold);
      expect(inherited?.fontFamily, language == 'ar' ? 'Tajawal' : 'Orbitron');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
