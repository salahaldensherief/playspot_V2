import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';
import 'package:playspot/features/profile/presentation/profile/widgets/profile_logout_listener.dart';
import '../support/local_translations_loader.dart';
import '../support/mock_profile_logout_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final language in ['ar', 'en']) {
    testWidgets(
      'logout cleanup failure is visible and localized in $language',
      (tester) async {
        final cubit = MockProfileLogoutCubit();
        final events = StreamController<ProfileState>.broadcast();
        when(
          () => cubit.state,
        ).thenReturn(const ProfileState(status: ProfileStatus.loggingOut));
        when(() => cubit.stream).thenAnswer((_) => events.stream);
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (context, _) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: BlocProvider<ProfileCubit>.value(
                    value: cubit,
                    child: const ProfileLogoutListener(
                      child: Scaffold(body: SizedBox()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        events.add(
          const ProfileState(
            status: ProfileStatus.error,
            errorMessage: 'auth.cache_cleanup_failed',
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.text(
            language == 'ar'
                ? 'تعذر مسح بيانات الحساب المحفوظة. يرجى المحاولة مرة أخرى.'
                : 'Saved account data could not be cleared. Please retry.',
          ),
          findsOneWidget,
        );
        expect(find.text('auth.cache_cleanup_failed'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await events.close();
      },
    );
  }

  testWidgets(
    'successful logout still navigates to the registered sign-in route',
    (tester) async {
      final cubit = MockProfileLogoutCubit();
      final events = StreamController<ProfileState>.broadcast();
      when(
        () => cubit.state,
      ).thenReturn(const ProfileState(status: ProfileStatus.loggingOut));
      when(() => cubit.stream).thenAnswer((_) => events.stream);
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => BlocProvider<ProfileCubit>.value(
              value: cubit,
              child: const ProfileLogoutListener(
                child: Scaffold(body: Text('profile-fixture')),
              ),
            ),
          ),
          GoRoute(
            path: '/sign-in',
            name: RouterKeys.signIn,
            builder: (_, _) => const Scaffold(body: Text('sign-in-fixture')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('profile-fixture'), findsOneWidget);
      events.add(const ProfileState(status: ProfileStatus.logoutSuccess));
      await tester.pumpAndSettle();
      expect(find.text('sign-in-fixture'), findsOneWidget);
      expect(find.text('profile-fixture'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await events.close();
    },
  );
}
