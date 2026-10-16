import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/profile/presentation/profile/widgets/profile_menu_section.dart';
import '../support/local_translations_loader.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final history in [false, true]) {
      testWidgets(
        'profile exposes ${history ? 'history' : 'tournaments'} without a promo ($language)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await EasyLocalization.ensureInitialized();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(
                  body: SingleChildScrollView(child: ProfileMenuSection()),
                ),
              ),
              GoRoute(
                path: RouterKeys.tournaments,
                name: RouterKeys.tournaments,
                builder: (_, _) =>
                    const Scaffold(body: Text('Tournament feed')),
              ),
              GoRoute(
                path: RouterKeys.tournamentHistory,
                name: RouterKeys.tournamentHistory,
                builder: (_, _) =>
                    const Scaffold(body: Text('Tournament history')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('ar')],
              startLocale: Locale(language),
              saveLocale: false,
              path: 'assets/lang',
              assetLoader: const LocalTranslationsLoader(),
              child: Builder(
                builder: (context) => ScreenUtilInit(
                  designSize: const Size(375, 812),
                  builder: (_, _) => MaterialApp.router(
                    routerConfig: router,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(
              (history
                      ? AppStrings.myTournamentHistory
                      : AppStrings.tournaments)
                  .tr(),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(history ? 'Tournament history' : 'Tournament feed'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
