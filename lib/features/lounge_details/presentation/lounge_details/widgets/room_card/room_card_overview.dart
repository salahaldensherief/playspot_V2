import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

import '../../room_card_presentation.dart';
import 'room_header.dart';
import 'room_quick_specs.dart';
import 'room_space_type_badge.dart';
import 'room_theme_extension.dart';

class RoomCardOverview extends StatelessWidget {
  final RoomModel room;
  final RoomCardPresentation data;
  final bool expanded;
  const RoomCardOverview({
    super.key,
    required this.room,
    required this.data,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        10,
        data.hasOffer(room) ? 30 : 10,
        10,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: room.themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  data.availabilityKey.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: data.isAvailable ? room.themeColor : Colors.white70,
                  ),
                ),
              ),
              RoomSpaceTypeBadge(
                room: room,
                isArabic: arabic,
                themeColor: room.themeColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          RoomHeader(
            room: room,
            isArabic: arabic,
            isAvailable: data.isAvailable,
            isExpanded: expanded,
            themeColor: room.themeColor,
          ),

          const SizedBox(height: 8),
          RoomQuickSpecs(room: room),
        ],
      ),
    );
  }
}
