import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/widgets/layout/section_header.dart';
import '../../support/local_translations_loader.dart';
import '../../support/mock_locale_cubit.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final language in ['ar', 'en']) {
    testWidgets(
      'large translated section header wraps and keeps see-all usable in $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locale = MockLocaleCubit();
        when(() => locale.state).thenReturn(Locale(language));
        var tapped = false;
        await tester.pumpWidget(
          EasyLocalization(
            key: ValueKey(language),
            supportedLocales: const [Locale('ar'), Locale('en')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: BlocProvider<LocaleCubit>.value(
                  value: locale,
                  child: Scaffold(
                    body: SectionHeader(
                      title: 'lounge_rooms_section',
                      onSeeAllTap: () => tapped = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('seeAll'.tr()));
        await tester.pumpAndSettle();
        expect(tapped, true);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
