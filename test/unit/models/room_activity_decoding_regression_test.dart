import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

void main() {
  test('RoomModel decodes canonical room activity relations', () {
    final room = RoomModel.fromJson({
      'id': 'room-1',
      'lounge_id': 'lounge-1',
      'name_en': 'Pool Table 1',
      'name_ar': 'ترابيزة بلياردو 1',
      'room_activities': [
        {
          'activity_type_id': 'activity-1',
          'activity_types': {
            'id': 'activity-1',
            'name': 'billiard',
            'label': 'Billiard / Pool',
            'category': 'table_sport',
            'icon_name': 'sports_pool',
          },
        },
      ],
      'space_types': {'name': 'open_area', 'label': 'Open Area'},
      'max_capacity': 2,
      'hourly_rate_single': 80,
      'hourly_rate_multi': 80,
      'is_available': true,
      'status': 'available',
      'images': <String>[],
      'features_ar': <String>[],
      'features_en': <String>[],
    });

    expect(room.activityNames, ['Billiard / Pool']);
    expect(room.spaceTypeName, 'open_area');
    expect(room.hasExpandableDetails, isTrue);
  });
}
