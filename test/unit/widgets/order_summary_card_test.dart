import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/cards/order_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderSummaryCard Widget Tests', () {
    testWidgets('renders title, subtitle, status badge, base cost, and grand total correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MediaQuery(
                data: const MediaQueryData(size: Size(375, 812)),
                child: const SingleChildScrollView(
                  child: OrderSummaryCard(
                    title: 'Test Lounge',
                    subtitle: 'VIP Room • PS5',
                    statusText: 'Pending',
                    statusColor: Colors.orange,
                    baseCostLabel: 'Original Room Price',
                    baseCostAmount: 150.0,
                    grandTotal: 155.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Lounge'), findsOneWidget);
      expect(find.text('VIP Room • PS5'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Original Room Price'), findsOneWidget);
      expect(find.text('150.00 EGP'), findsOneWidget);
      expect(find.text('155.00 EGP'), findsOneWidget);
    });
  });
}
