import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';
import 'package:playspot/features/active_session/domain/entities/canteen_combo.dart';
import 'package:playspot/features/active_session/domain/entities/order_item.dart';
import 'package:playspot/features/active_session/domain/entities/out_of_stock_item.dart';
import 'package:playspot/features/active_session/presentation/active_session_state.dart';
import 'package:playspot/features/active_session/presentation/widgets/canteen/canteen_combo_card.dart';
import 'package:playspot/features/active_session/presentation/widgets/canteen/canteen_dock_bar.dart';
import 'package:playspot/features/active_session/presentation/widgets/canteen/canteen_extra_card.dart';
import 'package:playspot/features/active_session/presentation/widgets/canteen/canteen_qty_stepper.dart';
import 'package:playspot/features/active_session/presentation/widgets/menu_bottom_sheet.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';
import '../support/mock_visual_session_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final (width, language) in [(320.0, 'ar'), (390.0, 'en')]) {
    testWidgets(
      'opening canteen refreshes stock and disables unavailable items $width $language',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = MockVisualSessionCubit();
        final now = DateTime.now();
        final state = ActiveSessionState(
          status: ActiveSessionStatus.loaded,
          session: ActiveSession(
            bookingId: 'booking',
            loungeId: 'lounge',
            loungeName: 'Lounge',
            roomName: 'Room',
            deviceName: 'Device',
            startTime: now,
            endTime: now.add(const Duration(hours: 1)),
            basePrice: 100,
            status: 'in_progress',
          ),
          menuStatus: ActionStatus.success,
          menu: const [
            ExtraModel(
              id: 'extra',
              name: 'Extra',
              price: 20,
              category: 'food',
              isAvailable: false,
            ),
          ],
          combos: const [
            CanteenCombo(
              id: 'combo',
              nameAr: 'Combo',
              price: 30,
              isAvailable: false,
            ),
          ],
        );
        var currentState = state;
        final states = StreamController<ActiveSessionState>.broadcast();
        addTearDown(states.close);
        when(() => cubit.state).thenAnswer((_) => currentState);
        when(() => cubit.stream).thenAnswer((_) => states.stream);
        when(
          () => cubit.loadMenu('lounge', forceRefresh: true),
        ).thenAnswer((_) async {});
        when(() => cubit.placeOrder(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: Builder(
              builder: (context) => ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, _) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Scaffold(body: MenuBottomSheet(cubit: cubit)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => cubit.loadMenu('lounge', forceRefresh: true)).called(1);
        final extraStepper = tester.widget<CanteenQtyStepper>(
          find.descendant(
            of: find.byType(CanteenExtraCard),
            matching: find.byType(CanteenQtyStepper),
          ),
        );
        final comboStepper = tester.widget<CanteenQtyStepper>(
          find.descendant(
            of: find.byType(CanteenComboCard),
            matching: find.byType(CanteenQtyStepper),
          ),
        );
        expect(extraStepper.onAdd, isNull);
        expect(comboStepper.onAdd, isNull);

        currentState = state.copyWith(
          menu: const [
            ExtraModel(id: 'extra', name: 'Extra', price: 20, category: 'food'),
          ],
        );
        states.add(currentState);
        await tester.pumpAndSettle();
        final availableStepper = tester.widget<CanteenQtyStepper>(
          find.descendant(
            of: find.byType(CanteenExtraCard),
            matching: find.byType(CanteenQtyStepper),
          ),
        );
        availableStepper.onAdd!();
        await tester.pump();
        expect(
          tester.widget<CanteenDockBar>(find.byType(CanteenDockBar)).totalCount,
          1,
        );

        currentState = state;
        states.add(currentState);
        await tester.pumpAndSettle();
        final dock = tester.widget<CanteenDockBar>(find.byType(CanteenDockBar));
        expect(dock.totalCount, 0);
        expect(dock.total, 0);

        // A server stock rejection overrides a still-available menu preview.
        currentState = state.copyWith(
          menu: const [
            ExtraModel(id: 'extra', name: 'Extra', price: 20, category: 'food'),
            ExtraModel(id: 'other', name: 'Other', price: 10, category: 'food'),
          ],
          combos: const [
            CanteenCombo(
              id: 'combo',
              nameAr: 'Combo',
              price: 30,
              items: [
                CanteenComboComponent(
                  extraId: 'extra',
                  nameAr: 'Extra',
                  quantity: 1,
                ),
              ],
            ),
          ],
        );
        states.add(currentState);
        await tester.pumpAndSettle();
        final extraCards = tester.widgetList<CanteenExtraCard>(
          find.byType(CanteenExtraCard),
        ).toList();
        final extraCard = extraCards.firstWhere((card) => card.item.id == 'extra');
        final otherCard = extraCards.firstWhere((card) => card.item.id == 'other');
        extraCard.onAdd();
        extraCard.onAdd();
        otherCard.onAdd();
        tester.widget<CanteenComboCard>(find.byType(CanteenComboCard)).onAdd();
        await tester.pump();

        currentState = currentState.copyWith(
          unavailableItems: const [
            OutOfStockItem(id: 'extra', name: 'Extra', available: 1, requested: 3),
          ],
        );
        states.add(currentState);
        await tester.pumpAndSettle();
        final limitedDock = tester.widget<CanteenDockBar>(
          find.byType(CanteenDockBar),
        );
        expect(limitedDock.totalCount, 2);
        expect(limitedDock.total, 30);
        expect(
          tester.widget<CanteenQtyStepper>(
            find.descendant(
              of: find.byType(CanteenComboCard),
              matching: find.byType(CanteenQtyStepper),
            ),
          ).qty,
          0,
        );

        currentState = currentState.copyWith(
          unavailableItems: const [
            OutOfStockItem(id: 'extra', name: 'Extra', available: 0, requested: 3),
          ],
        );
        states.add(currentState);
        await tester.pumpAndSettle();
        final rejectedDock = tester.widget<CanteenDockBar>(
          find.byType(CanteenDockBar),
        );
        expect(rejectedDock.totalCount, 1);
        expect(rejectedDock.total, 10);
        rejectedDock.onOrder();
        final orders = verify(() => cubit.placeOrder(captureAny())).captured;
        final items = orders.single as List<OrderItem>;
        expect(items.map((item) => item.id).toList(), ['other']);
      },
    );
  }
}
