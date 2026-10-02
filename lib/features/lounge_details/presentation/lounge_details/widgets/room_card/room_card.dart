import 'package:flutter/material.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_card_state.dart';

class RoomCard extends StatefulWidget {
  final RoomModel room;
  const RoomCard({super.key, required this.room});
  @override
  State<RoomCard> createState() => RoomCardState();
}
