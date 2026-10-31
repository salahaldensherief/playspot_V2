import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_comparison_facts.dart';

void main() {
  test('unknown room specifications do not become fabricated defaults', () {
    final room = RoomModel.fromJson({'id': 'r', 'name': 'VR room'});
    expect(room.controllersCount, 0);
    expect(room.screenSize, isEmpty);
    expect(room.maxCapacity, 0);
    expect(room.getFeatures(true), isEmpty);
    expect(room.getDisplayTitle(true), 'VR room');
  });
  test(
    'comparison uses all rooms, preserving base prices and localized features',
    () {
      final rooms = [
        RoomModel.fromJson({
          'id': 'a',
          'hourly_rate_single': 100,
          'max_capacity': 4,
          'activity_names': ['PS5'],
          'features_ar': ['تكييف', 'تكييف', ' '],
          'features_en': ['Air conditioning'],
          'has_discount': true,
          'discount_percentage': 25,
        }),
        RoomModel.fromJson({
          'id': 'b',
          'hourly_rate_single': 80,
          'max_capacity': 6,
          'activity_names': ['PS5', 'VR'],
          'features_ar': ['عزل صوتي'],
          'is_available': false,
        }),
      ];
      final facts = LoungeComparisonFacts.fromRooms(rooms, isArabic: true);
      expect(facts.roomCount, 2);
      expect(facts.minimumBaseRate, 80);
      expect(facts.maxCapacity, 6);
      expect(facts.activities, ['PS5', 'VR']);
      expect(facts.features, ['تكييف', 'عزل صوتي']);
      expect(rooms.first.effectivePrice, 75);
    },
  );
  test(
    'missing features and rates remain absent instead of invented amenities',
    () {
      final facts = LoungeComparisonFacts.fromRooms([
        RoomModel.fromJson({'id': 'r'}),
      ], isArabic: false);
      expect(facts.minimumBaseRate, isNull);
      expect(facts.maxCapacity, 0);
      expect(facts.features, isEmpty);
      expect(facts.activities, isEmpty);
    },
  );
  test(
    'room cache retains screen dimensions and joined activity categories',
    () {
      final room = RoomModel.fromJson({
        'id': 'r',
        'screen_size': '50"',
        'controllers_count': 0,
        'room_categories': [
          {
            'categories': {'name': 'Billiards'},
          },
        ],
      });
      final cached = RoomModel.fromJson(room.toJson());
      expect(cached.activityNames, ['Billiards']);
      expect(cached.screenSize, '50"');
      expect(cached.controllersCount, 0);
    },
  );
}
