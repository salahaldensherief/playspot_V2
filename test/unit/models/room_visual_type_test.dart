import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/room_card/room_theme_extension.dart';

void main() {
  test('room activity gives billiards and ping pong distinct presentation', () {
    final room = RoomModel.fromJson({
      'id': 'room',
      'space_type_slug': 'standard_room',
    });
    final openArea = RoomModel.fromJson({
      'id': 'open',
      'space_type_slug': 'open_area',
    });
    final billiards = RoomModel.fromJson({
      'id': 'pool',
      'activity_names': ['Billiards'],
    });
    final pingPong = RoomModel.fromJson({
      'id': 'ping',
      'activity_names': ['Table Tennis'],
    });

    expect(billiards.isBilliards, isTrue);
    expect(pingPong.isPingPong, isTrue);
    expect({
      room.themeColor,
      openArea.themeColor,
      billiards.themeColor,
      pingPong.themeColor,
    }, hasLength(4));
    expect({
      room.icon,
      openArea.icon,
      billiards.icon,
      pingPong.icon,
    }, hasLength(4));
  });
}
