import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_action_area.dart';
import 'room_booked_overlay.dart';
import 'room_header.dart';
import 'room_promo_badge.dart';
import 'room_quick_specs.dart';
import 'room_space_type_badge.dart';

class RoomMainContent extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isAvailable;
  final bool isSelected;
  final bool isExpanded;
  final Color themeColor;

  const RoomMainContent({
    super.key,
    required this.room,
    required this.isArabic,
    required this.isAvailable,
    required this.isSelected,
    required this.isExpanded,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding = room.hasActivePromo ? 18.h : 12.h;
    final horizontalPadding = 14.w;

    return IntrinsicHeight(
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RoomHeader(
                        room: room,
                        isArabic: isArabic,
                        isAvailable: isAvailable,
                        isExpanded: isExpanded,
                        themeColor: themeColor,
                      ),
                      RoomSpaceTypeBadge(
                          room: room, isArabic: isArabic, themeColor: themeColor),
                      RoomQuickSpecs(room: room),
                    ],
                  ),
                ),
              ),
              RoomActionArea(
                  room: room,
                  isAvailable: isAvailable,
                  isSelected: isSelected,
                  themeColor: themeColor),
            ],
          ),
          if (room.hasActivePromo)
            Positioned(
              top: 0,
              right: isArabic ? null : 0,
              left: isArabic ? 0 : null,
              child: RoomPromoBadge(
                  tag: room.getPromoTag(isArabic) ?? AppStrings.activeOffer.tr()),
            ),
          if (!isAvailable) const RoomBookedOverlay(),
        ],
      ),
    );
  }
}
