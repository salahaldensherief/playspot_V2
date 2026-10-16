import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/widgets/buttons/language_toggle_widget.dart';
import 'package:playspot/features/auth/presentation/widgets/auth_app_bar.dart';
import '../support/local_translations_loader.dart';

class _Locale extends MockCubit<Locale> implements LocaleCubit {}

class _Context extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(_Context()));
  for (final language in ['en', 'ar']) {
    testWidgets('auth language button receives a normal center tap $language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = _Locale();
      when(() => locale.state).thenReturn(Locale(language));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Column(children: [AuthAppBar(title: 'Sign in')]),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: Locale(language),
          saveLocale: false,
          path: 'assets/lang',
          assetLoader: const LocalTranslationsLoader(),
          child: BlocProvider<LocaleCubit>.value(
            value: locale,
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, _) => MaterialApp.router(
                  routerConfig: router,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageToggleWidget));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      verify(() => locale.toggleLocale(any())).called(1);
    });
  }
}
