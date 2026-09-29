import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_theme.dart';
import 'package:playspot/features/booking/domain/entities/booking_price_quote.dart';
import 'package:playspot/features/booking/presentation/widgets/price_changed_bottom_sheet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildTestableWidget(Widget child, Size screenSize) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: ScreenUtilInit(
          designSize: Size(screenSize.width, screenSize.height),
          builder: (context, _) => Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('PriceChangedBottomSheet Widget Tests', () {
    testWidgets('renders price updated alert with old & new prices and action buttons without overflow', (tester) async {
      const sampleQuote = BookingPriceQuote(
        segments: [
          PricingSegment(
            from: '16:00:00',
            to: '18:00:00',
            minutes: 120,
            baseRate: 50.0,
            ruleType: 'peak',
            rate: 75.0,
            amount: 150.0,
          ),
        ],
        roomSubtotal: 150.0,
        extraControllersAmount: 0.0,
        discountAmount: 0.0,
        total: 150.0,
        hasPeak: true,
        pricingVersion: 1,
      );

      await tester.pumpWidget(buildTestableWidget(
        const PriceChangedBottomSheet(
          oldPrice: 100.0,
          newPrice: 150.0,
          newQuote: sampleQuote,
        ),
        const Size(390, 844),
      ));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.priceUpdated.tr()), findsOneWidget);
      expect(find.text(AppStrings.proceedWithNewPrice.tr()), findsOneWidget);
      expect(find.text(AppStrings.cancel.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
