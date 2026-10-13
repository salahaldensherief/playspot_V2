import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/active_session/presentation/widgets/lounge_review_bottom_sheet.dart';
import '../support/local_translations_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Future<GlobalKey<NavigatorState>> mount(
    WidgetTester tester,
    Future<Either<Failure, void>> Function(double, String?) submit,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nav = GlobalKey<NavigatorState>();
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
            builder: (_, child) => MaterialApp(
              navigatorKey: nav,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: false,
                      enableDrag: false,
                      builder: (_) => LoungeReviewBottomSheet(
                        loungeName: 'Orbit',
                        onSubmit: submit,
                      ),
                    ),
                    child: const Text('Open review'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    return nav;
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
  }

  testWidgets('pending stays open, blocks duplicate taps and back/dismiss', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, void>>();
    var calls = 0;
    final nav = await mount(tester, (_, _) {
      calls++;
      return pending.future;
    });
    await tapSubmit(tester);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).behavior.isLoading,
      isTrue,
    );
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Thanks for your review!'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('review-close')))
          .onPressed,
      isNull,
    );
    await nav.currentState?.maybePop();
    await tester.pump();
    expect(find.byType(LoungeReviewBottomSheet), findsOneWidget);
    pending.complete(const Left(ServerFailure('reviewSubmissionFailed')));
    await tester.pumpAndSettle();
  });

  testWidgets('success dismisses only after backend result', (tester) async {
    final pending = Completer<Either<Failure, void>>();
    await mount(tester, (_, _) => pending.future);
    await tapSubmit(tester);
    expect(find.byType(LoungeReviewBottomSheet), findsOneWidget);
    pending.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(find.byType(LoungeReviewBottomSheet), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('backend failure displays error and permits retry', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      (_, _) async => ++calls == 1
          ? const Left(ServerFailure('reviewSubmissionFailed'))
          : const Right(null),
    );
    await tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-error')), findsOneWidget);
    expect(find.byType(LoungeReviewBottomSheet), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).behavior.isLoading,
      isFalse,
    );
    await tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(LoungeReviewBottomSheet), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('unexpected callback exception keeps retry available', (
    tester,
  ) async {
    await mount(tester, (_, _) async => throw StateError('transport failed'));
    await tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-error')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).behavior.isEnabled,
      isTrue,
    );
  });

  testWidgets(
    'late completion after forced removal does not pop the next page',
    (tester) async {
      final pending = Completer<Either<Failure, void>>();
      final nav = await mount(tester, (_, _) => pending.future);
      await tapSubmit(tester);
      final sheetContext = tester.element(find.byType(LoungeReviewBottomSheet));
      final sheetRoute = ModalRoute.of(sheetContext);
      if (sheetRoute == null) fail('Expected sheet route');
      nav.currentState?.removeRoute(sheetRoute);
      nav.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Next page')),
        ),
      );
      await tester.pumpAndSettle();
      pending.complete(const Right(null));
      await tester.pumpAndSettle();
      expect(find.text('Next page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late success does not pop a route above a mounted sheet', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, void>>();
    final nav = await mount(tester, (_, _) => pending.future);
    await tapSubmit(tester);
    nav.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next page')),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
