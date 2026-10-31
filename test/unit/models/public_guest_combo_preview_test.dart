import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/active_session/data/models/canteen_combo_model.dart';

void main() {
  test('public combo preview parses safe display fields for guests', () {
    final combo = CanteenComboModel.fromJson({
      'id': 'combo-friends',
      'name_ar': 'باقة تسالي الأصدقاء',
      'name_en': 'Friends snack combo',
      'description_ar': 'مياه ورقائق بطاطس لمشاركة الجلسة',
      'price': 84.6,
      'separate_items_price': 94,
      'savings': 9.4,
      'image_url': null,
      'is_available': true,
      'items': [
        {
          'extra_id': 'water',
          'name_ar': 'مياه',
          'name_en': 'Water',
          'price': 18,
          'quantity': 2,
        },
      ],
    });

    expect(combo.id, 'combo-friends');
    expect(combo.isAvailable, isTrue);
    expect(combo.price, 84.6);
    expect(combo.savings, closeTo(9.4, 0.0001));
    expect(combo.items.single.quantity, 2);
    expect(combo.getName(false), 'Friends snack combo');
  });

  test('empty and inactive combo lists are safe for a public preview', () {
    const emptyResponse = <Map<String, dynamic>>[];
    final empty = emptyResponse.map(CanteenComboModel.fromJson).toList();
    expect(empty, isEmpty);

    final unavailable = CanteenComboModel.fromJson({
      'id': 'unavailable',
      'name_ar': 'موقوف',
      'price': 12,
      'is_available': false,
      'items': [],
    });
    expect(unavailable.isAvailable, isFalse);
  });
}
