import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_screen.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_details_content.dart';
import '../support/local_translations_loader.dart';
import '../support/mock_locale_cubit.dart';
import '../support/mock_lounge_details_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final room = RoomModel.fromJson({
    'id': 'r',
    'lounge_id': 'l',
    'name_ar': 'غرفة PlayStation 5',
    'name_en': 'PlayStation 5 room',
    'activity_names': ['PS5'],
    'space_type_slug': 'standard_room',
    'max_capacity': 4,
    'hourly_rate_single': 100,
    'hourly_rate_multi': 150,
    'controllers_count': 2,
    'screen_size': '50"',
    'features_ar': ['تكييف', 'عزل صوتي'],
    'features_en': ['Air conditioning', 'Sound insulation'],
  });
  final busy = RoomModel.fromJson({
    'id': 'busy',
    'lounge_id': 'l',
    'name_ar': 'غرفة VR',
    'name_en': 'VR room',
    'activity_names': ['VR'],
    'space_type_slug': 'vip_room',
    'is_available': false,
    'status': 'occupied',
    'hourly_rate_single': 180,
  });
  final lounge = LoungeModel.fromJson({
    'id': 'l',
    'name': 'PlaySpot · Cairo',
    'image_url': '',
    'rating': 4.6,
    'total_reviews': 126,
    'distance_km': 3.974644,
    'latitude': 30.0444,
    'longitude': 31.2357,
    'location': 'القاهرة',
    'address': 'شارع التجمع الخامس، بجوار مركز الألعاب',
    'city': 'Cairo',
    'description_ar':
        'اختار الغرفة المناسبة لك، وقارن التجهيزات والسعر قبل ما تحجز.',
    'description_en':
        'Choose your room and compare its equipment and price before booking.',
    'opening_time': '10:00:00',
    'closing_time': '02:00:00',
    'wallet_number': 'fixture-wallet',
    'instapay_handle': 'fixture-handle',
    'require_prepaid_first_time': true,
  });
  final initial = LoungeDetailsState(
    status: LoungeDetailsStatus.success,
    lounge: lounge,
    rooms: [room, busy],
    selectedDate: DateTime.now(),
  );
  late MockLoungeDetailsCubit cubit;
  late MockLocaleCubit localeCubit;
  late StreamController<LoungeDetailsState> states;
  final capture = GlobalKey();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final pair in [
      ['Tajawal', 'assets/fonts/Tajawal/Tajawal-Regular.ttf'],
      ['Orbitron', 'assets/fonts/Orbitron/Orbitron-Regular.ttf'],
      ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
    ]) {
      await (FontLoader(pair[0])..addFont(rootBundle.load(pair[1]))).load();
    }
  });
  setUp(() {
    cubit = MockLoungeDetailsCubit();
    localeCubit = MockLocaleCubit();
    states = StreamController<LoungeDetailsState>.broadcast();
    whenListen(cubit, states.stream, initialState: initial);
    when(() => localeCubit.state).thenReturn(const Locale('ar'));
    when(() => cubit.init(lounge)).thenAnswer((_) {});
  });
  tearDown(() async {
    await states.close();
  });

  Future<void> mount(
    WidgetTester tester,
    double width,
    String locale,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    when(() => localeCubit.state).thenReturn(Locale(locale));
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('$width-$locale-$scale'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(locale),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: Builder(
            builder: (context) => ScreenUtilInit(
              designSize: DeviceTypeHelper.getSize(context),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: AppColors.scaffoldBackground,
                  textTheme: ThemeData.dark().textTheme.apply(
                    fontFamily: locale == 'ar' ? 'Tajawal' : 'Orbitron',
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: capture,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: BlocProvider<LocaleCubit>.value(
                  value: localeCubit,
                  child: BlocProvider<LoungeDetailsCubit>.value(
                    value: cubit,
                    child: LoungeDetailsScreen(lounge: lounge),
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
  }

  void expectClean(WidgetTester tester) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: exception?.toString());
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (directory == null) return;
    final boundary = capture.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Missing capture boundary');
    }
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Missing PNG bytes');
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      picture.dispose();
    });
  }

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('lounge page $width $locale scale=$scale', (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, width, locale, scale);
          expectClean(tester);
          expect(
            Directionality.of(
              tester.element(find.byType(LoungeDetailsContent)),
            ),
            locale == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          );
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-overview',
          );
          final controller = tester
              .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
              .controller;
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expectClean(tester);
          expect(find.byType(BackButtonWidget).hitTestable(), findsOneWidget);
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-rooms',
          );
          final card = find.byKey(const ValueKey('busy'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: card,
              matching: find.text(locale == 'ar' ? 'غرفة VR' : 'VR room'),
            ),
          );
          await tester.pumpAndSettle();
          expectClean(tester);
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-busy-expanded',
          );
          verifyNever(() => cubit.toggleRoomSelection('busy'));
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets(
    'room selection changes do not rebuild the lounge page or its overview',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, 360, 'ar', 1);
      final controller = tester
          .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
          .controller;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final counts = <String, int>{};
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        counts.update(
          element.widget.runtimeType.toString(),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      };
      final watch = Stopwatch()..start();
      try {
        for (var i = 0; i < 20; i++) {
          states.add(initial.copyWith(selectedRoomIds: i.isEven ? {'r'} : {}));
          await tester.pumpAndSettle();
        }
      } finally {
        debugOnRebuildDirtyWidget = previous;
        watch.stop();
      }
      expect(counts['LoungeDetailsScreen'] ?? 0, 0);
      expect(counts['LoungeDetailsContent'] ?? 0, 0);
      expect(counts['LoungeInfoSection'] ?? 0, 0);
      final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
      if (directory != null) {
        File('$directory/rebuild-measurement.json').writeAsStringSync(
          jsonEncode({
            'mode':
                'Flutter widget test/debug on Windows; synthetic data; not phone GPU timings',
            'selectionChanges': 20,
            'hostElapsedMicroseconds': watch.elapsedMicroseconds,
            'builds': counts,
          }),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
