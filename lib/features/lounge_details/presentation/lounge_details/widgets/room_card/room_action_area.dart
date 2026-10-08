import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

import '../../lounge_details_cubit.dart';
import '../../lounge_details_state.dart';
import '../../room_rate_presentation.dart';
import 'room_price_summary.dart';
import 'room_select_button.dart';

class RoomActionArea extends StatelessWidget {
  final RoomModel room;
  final bool isAvailable;
  final bool isSelected;
  final Color themeColor;
  const RoomActionArea({
    super.key,
    required this.room,
    required this.isAvailable,
    required this.isSelected,
    required this.themeColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
    buildWhen: (a, b) =>
        a.roomPlayModes[room.id] != b.roomPlayModes[room.id] ||
        a.roomExtraControllers[room.id] != b.roomExtraControllers[room.id] ||
        a.lounge != b.lounge,
    builder: (context, state) => Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final price = RoomPriceSummary(
            rate: RoomRatePresentation.fromState(room, state),
            color: themeColor,
          );
          if (!isAvailable) return price;
          final select = RoomSelectButton(
            roomId: room.id,
            selected: isSelected,
            color: themeColor,
          );
          if (constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [price, const SizedBox(height: 8), select],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: price),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 88, maxWidth: 132),
                child: select,
              ),
            ],
          );
        },
      ),
    ),
  );
}
