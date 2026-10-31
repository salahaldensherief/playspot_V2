import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/di.dart' as di;
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/auth/presentation/sign_up/signup_cubit.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/auth/presentation/sign_up/widgets/signup_form.dart';
import '../support/local_translations_loader.dart';

class _Auth extends Mock implements AuthRepository {}

class _Locale extends MockCubit<Locale> implements LocaleCubit {}

class _Profile extends Mock implements ProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('unauthenticated real sign-up route builds its screen', (
    tester,
  ) async {
    await di.sl.reset();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final auth = _Auth();
    final locale = _Locale();
    final signup = SignupCubit(auth, _Profile());
    when(auth.getCurrentUser).thenReturn(null);
    when(() => locale.state).thenReturn(const Locale('en'));
    di.sl.registerSingleton<AuthRepository>(auth);
    di.sl.registerSingleton<LocaleCubit>(locale);
    di.sl.registerSingleton<SignupCubit>(signup);
    final routes = AppRouter();
    routes.router.go(RouterKeys.signUp);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
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
    final error = tester.takeException();
    final formCount = find.byType(SignUpForm).evaluate().length;
    await tester.pumpWidget(const SizedBox.shrink());
    routes.router.dispose();
    await di.sl.reset();
    expect(
      error,
      isNull,
      reason:
          'Opening account creation must not require authenticated-only providers',
    );
    expect(formCount, 1);
  });
}
