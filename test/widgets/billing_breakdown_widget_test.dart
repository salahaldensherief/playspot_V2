import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/entities/order_item.dart';
import 'package:playspot/features/active_session/presentation/widgets/billing_breakdown.dart';
import '../support/local_translations_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal/Tajawal-Regular.ttf'));
    await font.load();
  });

  Future<void> pumpBreakdown(
    WidgetTester tester, {
    required ActiveSession session,
    String locale = 'ar',
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('test-$locale'),
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
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BillingBreakdownWidget(session: session),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BillingBreakdownWidget Tests', () {
    final now = DateTime.now();

    testWidgets(
      'running Open Time with zero canteen orders renders policy and pending notice only',
      (tester) async {
        final openSession = ActiveSession(
          bookingId: 'b_open_empty',
          loungeId: 'l1',
          loungeName: 'PlaySpot Lounge',
          roomName: 'VIP 1',
          deviceName: 'Station 1',
          startTime: now.subtract(const Duration(minutes: 40)),
          endTime: now,
          basePrice: 0.0,
          status: 'in_progress',
          isOpenTime: true,
          openTimePricingSnapshot: const {
            'effective_hourly_rate': 60.0,
            'minimum_minutes': 30,
            'rounding_minutes': 15,
          },
          orders: const [],
        );

        await pumpBreakdown(tester, session: openSession, locale: 'ar');

        // Policy texts must appear
        expect(find.text(AppStrings.openTimeElapsed.tr()), findsOneWidget);
        expect(
          find.text(AppStrings.openTimePolicy.tr(namedArgs: {'rate': '60.00'})),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStrings.openTimeMinimum.tr(namedArgs: {'minutes': '30'}),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStrings.openTimeRounding.tr(namedArgs: {'minutes': '15'}),
          ),
          findsOneWidget,
        );
        expect(find.text(AppStrings.openTimeBillPending.tr()), findsOneWidget);

        // No canteen orders card should appear
        expect(find.text(AppStrings.canteenMenu.tr()), findsNothing);
      },
    );

    testWidgets(
      'running Open Time with active canteen orders renders policy AND orders breakdown with subtotal',
      (tester) async {
        final openSessionWithOrders = ActiveSession(
          bookingId: 'b_open_orders',
          loungeId: 'l1',
          loungeName: 'PlaySpot Lounge',
          roomName: 'VIP 1',
          deviceName: 'Station 1',
          startTime: now.subtract(const Duration(minutes: 50)),
          endTime: now,
          basePrice: 0.0,
          status: 'in_progress',
          isOpenTime: true,
          openTimePricingSnapshot: const {
            'effective_hourly_rate': 75.0,
            'minimum_minutes': 30,
            'rounding_minutes': 15,
          },
          orders: const [
            OrderItem(
              id: 'c1',
              name: 'Pepsi',
              nameAr: 'بيبسي',
              price: 25.0,
              quantity: 2,
              status: 'delivered',
            ),
            OrderItem(
              id: 'c2',
              name: 'Doritos',
              nameAr: 'دوريتوس',
              price: 20.0,
              quantity: 1,
              status: 'preparing',
            ),
          ],
        );

        await pumpBreakdown(
          tester,
          session: openSessionWithOrders,
          locale: 'ar',
        );

        // Policy texts
        expect(find.text(AppStrings.openTimeElapsed.tr()), findsOneWidget);
        expect(find.text(AppStrings.openTimeBillPending.tr()), findsOneWidget);

        // Canteen card header
        expect(find.text(AppStrings.canteenMenu.tr()), findsOneWidget);

        // Items and quantities
        expect(find.text('بيبسي'), findsOneWidget);
        expect(find.text('دوريتوس'), findsOneWidget);
        expect(find.text('2×'), findsOneWidget);
        expect(find.text('1×'), findsOneWidget);

        // Status badges
        expect(find.text(AppStrings.orderStatusDelivered.tr()), findsOneWidget);
        expect(find.text(AppStrings.orderStatusPreparing.tr()), findsOneWidget);

        // Total canteen charge (25 * 2 + 20 * 1 = 70.00)
        expect(openSessionWithOrders.ordersTotal, 70.0);
        final expectedCanteenSummary = AppStrings.openTimeCanteenCharges.tr(
          namedArgs: {'amount': '70.00'},
        );
        expect(find.text(expectedCanteenSummary), findsWidgets);
      },
    );

    testWidgets(
      'running Open Time excludes cancelled canteen orders from chargeable subtotal',
      (tester) async {
        final openSessionCancelled = ActiveSession(
          bookingId: 'b_open_cancelled',
          loungeId: 'l1',
          loungeName: 'PlaySpot Lounge',
          roomName: 'VIP 1',
          deviceName: 'Station 1',
          startTime: now.subtract(const Duration(minutes: 30)),
          endTime: now,
          basePrice: 0.0,
          status: 'in_progress',
          isOpenTime: true,
          openTimePricingSnapshot: const {'effective_hourly_rate': 50.0},
          orders: const [
            OrderItem(
              id: 'c1',
              name: 'Burger',
              nameEn: 'Burger',
              price: 80.0,
              quantity: 1,
              status: 'delivered',
            ),
            OrderItem(
              id: 'c2',
              name: 'Water',
              nameEn: 'Water',
              price: 15.0,
              quantity: 2,
              status: 'cancelled',
            ),
          ],
        );

        await pumpBreakdown(
          tester,
          session: openSessionCancelled,
          locale: 'en',
        );

        // Burger (80) delivered + Water (30) cancelled -> Chargeable total = 80.00
        expect(openSessionCancelled.ordersTotal, 80.0);

        expect(find.text('Burger'), findsOneWidget);
        expect(find.text('Water'), findsOneWidget);
        expect(find.text(AppStrings.orderStatusDelivered.tr()), findsOneWidget);
        expect(find.text(AppStrings.orderStatusCancelled.tr()), findsOneWidget);

        final expectedSummary = AppStrings.openTimeCanteenCharges.tr(
          namedArgs: {'amount': '80.00'},
        );
        expect(find.text(expectedSummary), findsWidgets);
      },
    );

    testWidgets(
      'completed Open Time session renders full settled OrderSummaryCard with base price and grand total',
      (tester) async {
        final completedOpenSession = ActiveSession(
          bookingId: 'b_open_completed',
          loungeId: 'l1',
          loungeName: 'Apex Lounge',
          roomName: 'Arena A',
          deviceName: 'PC 10',
          startTime: now.subtract(const Duration(minutes: 90)),
          endTime: now,
          openTimeEndedAt: now,
          basePrice: 120.0, // Settled room_price by server
          status: 'completed',
          isOpenTime: true,
          orders: const [
            OrderItem(
              id: 'c1',
              name: 'Red Bull',
              nameAr: 'ريد بُل',
              price: 45.0,
              quantity: 1,
              status: 'delivered',
            ),
          ],
        );

        await pumpBreakdown(
          tester,
          session: completedOpenSession,
          locale: 'ar',
        );

        // Settled card header & status
        expect(find.text(AppStrings.billingBreakdown.tr()), findsOneWidget);
        expect(find.text(AppStrings.completed.tr()), findsOneWidget);

        // Base cost (120) + Canteen (45) = 165
        expect(completedOpenSession.grandTotal, 165.0);
        expect(find.text('ريد بُل'), findsOneWidget);
        expect(find.text(AppStrings.total.tr()), findsOneWidget);
      },
    );

    testWidgets(
      'fixed-duration active session preserves existing OrderSummaryCard display',
      (tester) async {
        final fixedSession = ActiveSession(
          bookingId: 'b_fixed',
          loungeId: 'l1',
          loungeName: 'PlaySpot Lounge',
          roomName: 'Console Room',
          deviceName: 'PS5',
          startTime: now.subtract(const Duration(minutes: 30)),
          endTime: now.add(const Duration(minutes: 30)),
          basePrice: 100.0,
          extensionsPrice: 30.0,
          status: 'in_progress',
          isOpenTime: false,
          orders: const [
            OrderItem(
              id: 'c1',
              name: 'Coffee',
              price: 20.0,
              quantity: 1,
              status: 'delivered',
            ),
          ],
        );

        await pumpBreakdown(tester, session: fixedSession, locale: 'en');

        expect(find.text(AppStrings.billingBreakdown.tr()), findsOneWidget);
        expect(find.text(AppStrings.baseCost.tr()), findsOneWidget);
        expect(find.text(AppStrings.extensions.tr()), findsOneWidget);
        expect(find.text('Coffee'), findsOneWidget);
        expect(fixedSession.grandTotal, 150.0);
      },
    );
  });
}
