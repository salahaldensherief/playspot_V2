import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/profile/data/datasources/remote/support_remote_data_source.dart';
import 'package:playspot/features/profile/presentation/support/help_support_screen.dart';
import 'package:playspot/features/profile/presentation/legal/terms_and_conditions_screen.dart';
import '../support/local_translations_loader.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/presentation/quick_rebook_cubit.dart';
import 'package:playspot/features/my_bookings/presentation/quick_rebook_state.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/quick_rebook_bottom_sheet.dart';

class FixtureQuickRebook extends Cubit<QuickRebookState>
    implements QuickRebookCubit {
  int retries = 0;
  FixtureQuickRebook()
    : super(
        QuickRebookState(
          status: QuickRebookStatus.error,
          selectedDate: DateTime(2026, 11, 1),
        ),
      );
  @override
  Future<void> changeDate(DateTime date) async {
    retries++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureSupport implements SupportRemoteDataSource {
  bool fail = true;
  bool empty = false;
  int loads = 0;
  @override
  Future<Map<String, dynamic>> getSupportSettings() async {
    loads++;
    if (fail) throw StateError('synthetic outage');
    return empty ? {} : {'support_phone': '01000000000'};
  }

  @override
  Future<List<Map<String, dynamic>>> getFaqs(String lang) async => empty
      ? []
      : [
          {'question': 'Fixture FAQ', 'answer': 'Fixture answer'},
        ];
  @override
  Future<List<Map<String, dynamic>>> getPolicies(String lang) async {
    loads++;
    if (fail) throw StateError('synthetic outage');
    if (empty) return [];
    return [
      {
        'policy_key': 'terms',
        'title': 'Fixture title',
        'content': 'Fixture reviewed policy',
      },
    ];
  }

  @override
  Future<void> createSupportTicket({
    required String issueType,
    required String message,
  }) async {}
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() async => sl.reset());
  Future<void> mount(
    WidgetTester tester,
    String locale,
    Widget child,
    FixtureSupport fixture,
  ) async {
    sl.registerSingleton<SupportRemoteDataSource>(fixture);
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(locale),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: ScreenUtilInit(
          designSize: const Size(360, 800),
          builder: (context, _) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in ['ar', 'en']) {
    testWidgets('unpublished policies show no replacement legal text $locale', (
      tester,
    ) async {
      final fixture = FixtureSupport()
        ..fail = false
        ..empty = true;
      await mount(tester, locale, const TermsAndConditionsScreen(), fixture);
      expect(find.text('policyContentUnavailable'.tr()), findsOneWidget);
      expect(find.textContaining('Acceptance of Terms'), findsNothing);
      expect(find.textContaining('قبول الشروط'), findsNothing);
    });
    testWidgets(
      'language reload clears content absent from the new response $locale',
      (tester) async {
        final fixture = FixtureSupport()..fail = false;
        await mount(tester, locale, const TermsAndConditionsScreen(), fixture);
        expect(find.text('Fixture reviewed policy'), findsOneWidget);
        fixture.empty = true;
        await tester
            .element(find.byType(TermsAndConditionsScreen))
            .setLocale(Locale(locale == 'ar' ? 'en' : 'ar'));
        await tester.pumpAndSettle();
        expect(find.text('Fixture reviewed policy'), findsNothing);
        expect(find.text('policyContentUnavailable'.tr()), findsOneWidget);
      },
    );
    testWidgets(
      'Quick Rebook request error differs from unavailable setup and permits retry $locale',
      (tester) async {
        final cubit = FixtureQuickRebook();
        final booking = BookingModel.fromJson({
          'id': 'fixture',
          'date': '2026-10-01',
          'start_time': '18:00:00',
          'end_time': '19:00:00',
          'status': 'completed',
        });
        await mount(
          tester,
          locale,
          Scaffold(
            body: BlocProvider<QuickRebookCubit>.value(
              value: cubit,
              child: QuickRebookBottomSheet(booking: booking),
            ),
          ),
          FixtureSupport(),
        );
        expect(find.text('quickRebookSlotsLoadFailed'.tr()), findsOneWidget);
        expect(
          find.text(AppStrings.quickRebookUnavailableMessage.tr()),
          findsNothing,
        );
        await tester.tap(find.text(AppStrings.retry.tr()));
        await tester.pumpAndSettle();
        expect(cubit.retries, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await cubit.close();
      },
    );
    testWidgets(
      'support outage hides placeholder contacts and retry loads actual content $locale',
      (tester) async {
        final fixture = FixtureSupport();
        await mount(tester, locale, const HelpSupportScreen(), fixture);
        expect(
          find.byKey(const ValueKey('support-load-error')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.supportCall.tr()), findsNothing);
        expect(find.textContaining('01012345678'), findsNothing);
        fixture.fail = false;
        await tester.tap(
          find.widgetWithText(TextButton, AppStrings.retry.tr()),
        );
        await tester.pumpAndSettle();
        expect(fixture.loads, 2);
        expect(find.byKey(const ValueKey('support-load-error')), findsNothing);
        expect(find.text(AppStrings.supportCall.tr()), findsOneWidget);
        expect(find.text('Fixture FAQ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'legitimate empty support configuration has no fabricated contacts $locale',
      (tester) async {
        final fixture = FixtureSupport()
          ..fail = false
          ..empty = true;
        await mount(tester, locale, const HelpSupportScreen(), fixture);
        expect(find.byKey(const ValueKey('support-load-error')), findsNothing);
        expect(find.text(AppStrings.supportCall.tr()), findsNothing);
        expect(find.text(AppStrings.supportWhatsApp.tr()), findsNothing);
        expect(find.text(AppStrings.supportEmail.tr()), findsNothing);
        expect(find.text('Fixture FAQ'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'policy request failure shows retry instead of fallback policy $locale',
      (tester) async {
        final fixture = FixtureSupport();
        await mount(tester, locale, const TermsAndConditionsScreen(), fixture);
        expect(find.text('supportDataLoadFailed'.tr()), findsOneWidget);
        fixture.fail = false;
        await tester.tap(
          find.widgetWithText(TextButton, AppStrings.retry.tr()),
        );
        await tester.pumpAndSettle();
        expect(fixture.loads, 2);
        expect(find.text('Fixture reviewed policy'), findsOneWidget);
        expect(find.text('supportDataLoadFailed'.tr()), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
