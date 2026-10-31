import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/features/home/presentation/widgets/home_sliver_app_bar.dart';
import 'package:playspot/features/notifications/presentation/notifications_cubit.dart';
import 'package:playspot/features/notifications/presentation/notifications_state.dart';
import '../support/local_translations_loader.dart';

class _Home extends MockCubit<HomeState> implements HomeCubit {}

class _Locale extends MockCubit<Locale> implements LocaleCubit {}

class _Notifications extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final pair in [
      ['Tajawal', 'assets/fonts/Tajawal/Tajawal-Regular.ttf'],
      ['Orbitron', 'assets/fonts/Orbitron/Orbitron-Regular.ttf'],
    ]) {
      await (FontLoader(pair[0])..addFont(rootBundle.load(pair[1]))).load();
    }
  });
  for (final language in ['ar', 'en']) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final cities in [false, true]) {
        testWidgets(
          'short-phone header fits $language scale $scale cities $cities',
          (tester) async {
            tester.view.physicalSize = const Size(360, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final home = _Home(),
                locale = _Locale(),
                notifications = _Notifications();
            when(() => home.state).thenReturn(
              HomeState(
                pointsBalance: 600,
                availableCities: cities
                    ? [
                        {'city': 'مدينة الاختبار'},
                        {'city': 'QA City'},
                      ]
                    : [],
              ),
            );
            when(() => locale.state).thenReturn(Locale(language));
            when(
              () => notifications.state,
            ).thenReturn(const NotificationsState());
            await tester.pumpWidget(
              EasyLocalization(
                supportedLocales: const [Locale('en'), Locale('ar')],
                startLocale: Locale(language),
                saveLocale: false,
                path: 'assets/lang',
                assetLoader: const LocalTranslationsLoader(),
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<HomeCubit>.value(value: home),
                    BlocProvider<LocaleCubit>.value(value: locale),
                    BlocProvider<NotificationsCubit>.value(
                      value: notifications,
                    ),
                  ],
                  child: Builder(
                    builder: (context) => ScreenUtilInit(
                      designSize: const Size(375, 812),
                      builder: (_, _) => MaterialApp(
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: child!,
                        ),
                        home: const Scaffold(
                          body: CustomScrollView(
                            slivers: [
                              HomeSliverAppBar(
                                userName: 'QA customer',
                                currentLocation: '',
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 1400,
                                  child: Text('Lounge content'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(AppStrings.locationUnavailable.tr()),
              findsOneWidget,
            );
            expect(find.textContaining('SEARCHING'), findsNothing);
            expect(tester.takeException(), isNull);
            expect(
              tester.widget<SliverAppBar>(find.byType(SliverAppBar)).pinned,
              isTrue,
            );
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -450),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
