import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/booking_card.dart';
import '../support/local_translations_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final (family, path) in [
      ('Tajawal', 'assets/fonts/Tajawal/Tajawal-Regular.ttf'),
      ('Orbitron', 'assets/fonts/Orbitron/Orbitron-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  final booking = BookingModel(
    id: 'fixture',
    loungeName: 'PlaySpot',
    loungeLocation: 'القاهرة',
    roomName: 'غرفة ٤',
    controllersCount: 2,
    screenSize: '43"',
    date: DateTime(2026, 9, 27),
    startTime: '12:45:00',
    endTime: '13:45:00',
    status: BookingStatus.completed,
    paymentStatus: 'paid',
    totalPrice: 100,
    startDateTime: DateTime(2026, 9, 27, 12, 45),
    lat: 30.0444,
    lng: 31.2357,
  );
  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final language in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('booking card $width $language text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            EasyLocalization(
              supportedLocales: const [Locale('ar'), Locale('en')],
              startLocale: Locale(language),
              saveLocale: false,
              path: 'assets/lang',
              assetLoader: const LocalTranslationsLoader(),
              child: Builder(
                builder: (context) => ScreenUtilInit(
                  designSize: DeviceTypeHelper.getSize(context),
                  minTextAdapt: true,
                  builder: (context, _) => MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    theme: ThemeData.dark().copyWith(
                      scaffoldBackgroundColor: AppColors.scaffoldBackground,
                    ),
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: Size(width, 1000),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Scaffold(
                        body: Center(
                          child: SingleChildScrollView(
                            child: RepaintBoundary(
                              key: capture,
                              child: ColoredBox(
                                color: AppColors.scaffoldBackground,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: width.clamp(0, 600),
                                    child: BookingCard(booking: booking),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(booking.date.toAppDateString(locale: language)),
            findsOneWidget,
          );
          if (language == 'ar') {
            expect(find.textContaining('Sunday'), findsNothing);
            expect(find.textContaining('PM'), findsNothing);
          }
          for (final element in find.byType(ButtonContentWidget).evaluate()) {
            final finder = find.byWidget(element.widget);
            final text = find.descendant(
              of: finder,
              matching: find.byType(Text),
            );
            if (text.evaluate().isNotEmpty) {
              expect(
                tester.widget<Text>(text.first).textAlign,
                TextAlign.center,
              );
            }
          }
          for (final element in find.byType(AppButton).evaluate()) {
            expect(
              tester.getSize(find.byWidget(element.widget)).height,
              greaterThanOrEqualTo(48),
            );
          }
          final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
          if (directory != null)
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(directory).create(recursive: true);
              await File(
                '$directory/booking-${width.toInt()}-$language-$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
