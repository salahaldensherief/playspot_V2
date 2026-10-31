import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

void main() {
  test('joined percentage promotion wins over unrelated flat fixed fields', () {
    final room = RoomModel.fromJson({
      'id': 'r',
      'hourly_rate_single': 200,
      'discount_type': 'fixed',
      'promotions': [
        {'discount_percentage': 25, 'tag_en': ' ', 'title_en': 'Weekend'},
      ],
    });
    expect(room.promoDiscountType, 'percentage');
    expect(room.effectivePrice, 150);
    expect(room.promoTagEn, 'Weekend');
  });
  test('blank promotion labels fall back to nonblank real labels', () {
    final room = RoomModel.fromJson({
      'id': 'r',
      'tag_en': 'Flat offer',
      'promotions': [
        {'discount_percentage': 20, 'tag_en': ''},
      ],
    });
    expect(room.promoTagEn, 'Flat offer');
    final lounge = LoungeModel.fromJson({
      'discount_title_en': '',
      'promotions': [
        {'discount_percentage': 20, 'tag_en': ' ', 'title_en': 'Real offer'},
      ],
    });
    expect(lounge.getDiscountTitle(false), 'Real offer');
  });
  test(
    'expired and inactive joined room promotions cannot create price reductions',
    () {
      final room = RoomModel.fromJson({
        'id': 'r',
        'hourly_rate_single': 200,
        'promotions': [
          {'discount_percentage': 50, 'expires_at': '2020-01-01T00:00:00Z'},
          {'discount_percentage': 50, 'is_active': false},
        ],
      });
      expect(room.hasActivePromo, false);
      expect(room.effectivePrice, 200);
    },
  );
}
