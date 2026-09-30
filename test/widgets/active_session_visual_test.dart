import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/presentation/active_session_cubit.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';
import 'package:playspot/features/active_session/presentation/widgets/active_session_body.dart';
import '../support/local_translations_loader.dart';
import 'package:playspot/features/active_session/presentation/widgets/extend_session_button.dart';
import 'package:playspot/features/active_session/presentation/widgets/extension_bottom_sheet.dart';
import 'package:playspot/features/active_session/presentation/widgets/quick_actions.dart';
import '../support/mock_visual_session_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  final session = ActiveSession(
    bookingId: 'visual',
    loungeId: 'l',
    loungeName: 'بلاي سبوت',
    roomName: 'غرفة ١',
    deviceName: 'PlayStation 5',
    startTime: now.subtract(const Duration(minutes: 10)),
    endTime: now.add(const Duration(minutes: 50)),
    basePrice: 125,
    status: 'in_progress',
  );
  final cubit = MockVisualSessionCubit();
  when(() => cubit.state).thenReturn(
    ActiveSessionState(status: ActiveSessionStatus.loaded, session: session),
  );
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => cubit.calculateExtensionCost(any())).thenReturn(30);
  final captureKey = GlobalKey();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal/Tajawal-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final english = FontLoader('Orbitron')
      ..addFont(rootBundle.load('assets/fonts/Orbitron/Orbitron-Regular.ttf'));
    await english.load();
  });

  Future<void> mount(
    WidgetTester tester,
    double width,
    String locale,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('$width-$locale-$scale'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(locale),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: captureKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData.dark().copyWith(
                scaffoldBackgroundColor: AppColors.scaffoldBackground,
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Tajawal',
                ),
              ),
              home: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SizedBox(
                    child: BlocProvider<ActiveSessionCubit>.value(
                      value: cubit,
                      child: const ActiveSessionBody(),
                    ),
                  ),
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
    await tester.pump();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (directory == null) return;
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('mobile $width $locale text=$scale', (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, width, locale, scale);
          expect(tester.takeException(), isNull);
          expect(find.textContaining(session.roomName), findsWidgets);
          await screenshot(tester, 'mobile-${width.toInt()}-$locale-$scale');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('extension requires opening sheet, selecting and confirming', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => cubit.requestExtension(any())).thenAnswer((_) async {});
    await mount(tester, 360, 'ar', 1.6);
    expect(find.byType(QuickActions), findsNothing);
    verifyNever(() => cubit.requestExtension(any()));
    await tester.tap(find.byType(ExtendSessionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ExtensionBottomSheet), findsOneWidget);
    await screenshot(tester, 'mobile-extension-sheet-360-ar-1.6');
    verifyNever(() => cubit.requestExtension(any()));
    await tester.tap(find.byKey(const ValueKey('extension-option-30')));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.requestExtension(any()));
    await tester.tap(find.byKey(const ValueKey('extension-confirm')));
    await tester.pumpAndSettle();
    verify(() => cubit.requestExtension(30)).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timer ticks do not rebuild session body', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1);
    final counts = <String, int>{};
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final name = element.widget.runtimeType.toString();
      counts.update(name, (n) => n + 1, ifAbsent: () => 1);
    };
    final watch = Stopwatch()..start();
    try {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
    watch.stop();
    expect(counts['ActiveSessionBody'] ?? 0, 0);
    expect(counts['TimerWidget'] ?? 0, greaterThan(0));
    final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (directory != null)
      File('$directory/../mobile-rebuild-measurement.json').writeAsStringSync(
        jsonEncode({
          'mode':
              'Flutter widget test, debug, Windows host; not phone GPU timings',
          'simulatedSeconds': 10,
          'hostElapsedMicroseconds': watch.elapsedMicroseconds,
          'builds': counts,
        }),
      );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
