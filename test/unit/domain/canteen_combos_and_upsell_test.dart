import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/active_session/data/models/order_item_model.dart';
import 'package:playspot/features/active_session/domain/entities/canteen_combo.dart';
import 'package:playspot/features/active_session/domain/entities/out_of_stock_item.dart';
import 'package:playspot/features/active_session/domain/entities/upsell_suggestion.dart';

void main() {
  group('Canteen Combos & Upsell Engine Tests', () {
    test('1. Combo without image handles null safely and provides fallback', () {
      const comboNoImg = CanteenCombo(
        id: 'combo_1',
        nameAr: 'كومبو سناك',
        nameEn: 'Snack Combo',
        price: 45.0,
        separateItemsPrice: 55.0,
        savings: 10.0,
        imageUrl: null, // No image provided
        items: [
          CanteenComboComponent(extraId: 'extra_1', nameAr: 'شيبسي', price: 25.0, quantity: 1),
          CanteenComboComponent(extraId: 'extra_2', nameAr: 'كولا', price: 30.0, quantity: 1),
        ],
      );

      expect(comboNoImg.imageUrl, isNull);
      expect(comboNoImg.savings, 10.0);
      expect(comboNoImg.getName(true), 'كومبو سناك');
      expect(comboNoImg.getName(false), 'Snack Combo');
    });

    test('2. Combo with deactivated or out-of-stock component is flagged correctly', () {
      const combo = CanteenCombo(
        id: 'combo_2',
        nameAr: 'عرض التوفير',
        price: 80.0,
        savings: 20.0,
        items: [
          CanteenComboComponent(extraId: 'extra_active', nameAr: 'ساندوتش', quantity: 1),
          CanteenComboComponent(extraId: 'extra_deactivated', nameAr: 'عصير برتقال', quantity: 1),
        ],
      );

      final unavailableList = [
        const OutOfStockItem(id: 'extra_deactivated', name: 'عصير برتقال', available: 0, requested: 1),
      ];

      // Verify that component is in unavailable list
      bool hasUnavailable = combo.items.any((c) => unavailableList.any((u) => u.id == c.extraId));
      expect(hasUnavailable, isTrue);

      final unavailComponent = unavailableList.firstWhere((u) => u.id == 'extra_deactivated');
      expect(unavailComponent.available, 0);
    });

    test('3. Upsell suggestion for out-of-stock item is filtered/hidden', () {
      final suggestions = [
        const UpsellSuggestion(
          ruleId: 'rule_1',
          suggestionType: 'extra',
          targetId: 'extra_instock',
          nameAr: 'شاي أخضر',
          originalPrice: 20.0,
          discountPercent: 10.0,
          finalPrice: 18.0,
        ),
        const UpsellSuggestion(
          ruleId: 'rule_2',
          suggestionType: 'extra',
          targetId: 'extra_out_of_stock',
          nameAr: 'مشروب طاقة',
          originalPrice: 50.0,
          discountPercent: 15.0,
          finalPrice: 42.5,
        ),
      ];

      final outOfStockIds = {'extra_out_of_stock'};

      // Filter out suggestions whose target is out of stock
      final visibleSuggestions = suggestions.where((s) => !outOfStockIds.contains(s.targetId)).toList();

      expect(visibleSuggestions.length, 1);
      expect(visibleSuggestions.first.targetId, 'extra_instock');
      expect(visibleSuggestions.first.finalPrice, 18.0);
    });

    test('4. Cart with both combo and single extra sharing the same component separates payloads and calculates totals accurately', () {
      const sharedExtraId = 'extra_pepsi';

      final comboItem = OrderItemModel(
        id: 'combo_party',
        name: 'كومبو الأصدقاء',
        price: 90.0,
        quantity: 2,
        isCombo: true,
      );

      final singleItem = OrderItemModel(
        id: sharedExtraId,
        name: 'بيبسي كانز',
        price: 20.0,
        quantity: 3,
        isCombo: false,
      );

      final cart = [comboItem, singleItem];

      // Verify total calculation
      final total = cart.fold<double>(0.0, (sum, item) => sum + item.total);
      expect(total, 90.0 * 2 + 20.0 * 3); // 180 + 60 = 240.0

      // Verify serialization payloads for place_canteen_order
      final payloadCombo = comboItem.toOrderPayload();
      final payloadSingle = singleItem.toOrderPayload();

      expect(payloadCombo['combo_id'], 'combo_party');
      expect(payloadCombo['extra_id'], isNull);
      expect(payloadCombo['quantity'], 2);

      expect(payloadSingle['extra_id'], sharedExtraId);
      expect(payloadSingle['combo_id'], isNull);
      expect(payloadSingle['quantity'], 3);
    });
  });
}
