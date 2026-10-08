import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../lounge_details_cubit.dart';
import '../../lounge_details_state.dart';
import '../../room_card_presentation.dart';
import 'room_card.dart';
import 'room_card_body.dart';

class RoomCardState extends State<RoomCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) =>
      BlocListener<LoungeDetailsCubit, LoungeDetailsState>(
        listenWhen: (a, b) =>
            !a.isRoomSelected(widget.room.id) &&
            b.isRoomSelected(widget.room.id),
        listener: (context, state) {
          if (!_expanded) setState(() => _expanded = true);
        },
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          buildWhen: (a, b) =>
              a.isRoomSelected(widget.room.id) !=
                  b.isRoomSelected(widget.room.id) ||
              a.bookedRoomIds.contains(widget.room.id) !=
                  b.bookedRoomIds.contains(widget.room.id) ||
              a.lounge != b.lounge ||
              a.operatingStatus != b.operatingStatus,
          builder: (context, state) => RoomCardBody(
            room: widget.room,
            data: RoomCardPresentation.fromState(widget.room, state),
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ),
      );
}
