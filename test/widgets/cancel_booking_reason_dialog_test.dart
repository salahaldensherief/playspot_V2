import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/my_bookings/presentation/widgets/cancel_booking_reason_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('customer must provide a reason before cancelling', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<String>(
                        context: context,
                        builder: (_) => const CancelBookingReasonDialog(),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a cancellation reason'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byKey(const ValueKey(AppStrings.cancelReasonOther)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family emergency');
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();
    expect(result, 'Family emergency');
  });
}
