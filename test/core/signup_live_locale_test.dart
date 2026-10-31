import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/di.dart' as di;
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/auth/presentation/sign_up/signup_cubit.dart';
import 'package:playspot/features/auth/presentation/sign_up/widgets/signup_form.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import '../support/local_translations_loader.dart';

class _Auth extends Mock implements AuthRepository {}

class _Profile extends Mock implements ProfileRepository {}

class _Preferences extends Mock implements PreferenceManager {}

void main() {
  for (final start in ['ar', 'en']) {
    testWidgets(
      'real signup translates labels while preserving typed data from $start',
      (tester) async {
        await di.sl.reset();
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        final auth = _Auth(), preferences = _Preferences();
        when(auth.getCurrentUser).thenReturn(null);
        when(() => preferences.currentLang()).thenReturn(start);
        when(() => preferences.saveLanguage(any())).thenAnswer((_) async {});
        final locale = LocaleCubit(preferenceManager: preferences);
        final signup = SignupCubit(auth, _Profile());
        di.sl.registerSingleton<AuthRepository>(auth);
        di.sl.registerSingleton<LocaleCubit>(locale);
        di.sl.registerSingleton<SignupCubit>(signup);
        final routes = AppRouter();
        routes.router.go(RouterKeys.signUp);
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(start),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(375, 812),
                builder: (_, _) => MaterialApp.router(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  routerConfig: routes.router,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final nameField = find.byWidgetPredicate(
          (w) => w is TextFormField && w.controller == signup.nameController,
        );
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Unsaved QA name');
        locale.toggleLocale(tester.element(find.byType(SignUpForm)));
        await tester.pumpAndSettle();
        final target = start == 'en' ? 'ar' : 'en';
        final strings = await const LocalTranslationsLoader().load(
          'assets/lang',
          Locale(target),
        );
        expect(
          find.text(strings[AppStrings.createAnAcc] as String),
          findsOneWidget,
        );
        expect(find.text(strings[AppStrings.name] as String), findsOneWidget);
        expect(signup.nameController.text, 'Unsaved QA name');
        expect(
          routes.router.routeInformationProvider.value.uri.path,
          RouterKeys.signUp,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        routes.router.dispose();
        await locale.close();
        await di.sl.reset();
      },
    );
  }
}
