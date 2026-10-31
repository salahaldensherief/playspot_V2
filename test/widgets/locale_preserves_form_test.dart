import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import '../support/local_translations_loader.dart';

class _Preferences extends Mock implements PreferenceManager {}

void main() {
  for (final start in ['en', 'ar']) {
    testWidgets(
      'changing language preserves the route and typed form ($start)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        final preferences = _Preferences();
        when(() => preferences.currentLang()).thenReturn(start);
        when(() => preferences.saveLanguage(any())).thenAnswer((_) async {});
        final cubit = LocaleCubit(preferenceManager: preferences);
        addTearDown(cubit.close);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final router = GoRouter(
          initialLocation: '/signup',
          routes: [
            GoRoute(
              path: '/signup',
              builder: (context, _) => Scaffold(
                body: Column(
                  children: [
                    TextField(controller: controller),
                    Text(context.locale.languageCode),
                    TextButton(
                      onPressed: () => cubit.toggleLocale(context),
                      child: const Text('Change language'),
                    ),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: '/splash',
              name: RouterKeys.splash,
              builder: (_, _) =>
                  const Scaffold(body: Text('Unexpected splash')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(start),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: Builder(
              builder: (context) => MaterialApp.router(
                routerConfig: router,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Unsaved profile name');
        await tester.tap(find.text('Change language'));
        await tester.pumpAndSettle();
        final target = start == 'en' ? 'ar' : 'en';
        expect(find.text(target), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/signup');
        expect(find.text('Unexpected splash'), findsNothing);
        expect(find.text('Unsaved profile name'), findsOneWidget);
        expect(cubit.state.languageCode, target);
        verify(() => preferences.saveLanguage(target)).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
