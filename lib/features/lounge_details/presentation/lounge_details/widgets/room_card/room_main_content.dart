import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../room_card_presentation.dart';
import 'room_action_area.dart';
import 'room_booked_overlay.dart';
import 'room_header.dart';
import 'room_promo_badge.dart';
import 'room_quick_specs.dart';
import 'room_space_type_badge.dart';
import 'room_theme_extension.dart';

class RoomMainContent extends StatelessWidget {
  final RoomModel room;
  final RoomCardPresentation data;
  final bool expanded;

  const RoomMainContent({
    super.key,
    required this.room,
    required this.data,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final hasOffer = data.hasOffer(room);
    final verticalPadding = hasOffer ? 18.h : 12.h;
    final horizontalPadding = 14.w;

    final String offerText = () {
      final tag = room.hasActivePromo
          ? room.getPromoTag(isArabic)
          : data.lounge?.getDiscountTitle(isArabic);
      if (tag != null &&
          tag.trim().isNotEmpty &&
          (isArabic || !RegExp(r'[\u0600-\u06FF]').hasMatch(tag))) {
        return tag;
      }
      final pct = room.hasActivePromo && room.promoDiscountValue > 0
          ? room.promoDiscountValue.toInt()
          : (data.lounge?.discountPercentage ?? 0);
      if (pct > 0) {
        return AppStrings.roomDiscountPercent.tr(
          namedArgs: {'percent': pct.toString()},
        );
      }
      return AppStrings.activeOffer.tr();
    }();

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
                        isAvailable: data.isAvailable,
                        isExpanded: expanded,
                        themeColor: room.themeColor,
                      ),
                      const SizedBox(height: 6),
                      RoomSpaceTypeBadge(
                        room: room,
                        isArabic: isArabic,
                        themeColor: room.themeColor,
                      ),
                      const SizedBox(height: 6),
                      RoomQuickSpecs(room: room),
                    ],
                  ),
                ),
              ),
              RoomActionArea(
                room: room,
                isAvailable: data.isAvailable,
                isSelected: data.isSelected,
                themeColor: room.themeColor,
              ),
            ],
          ),
          if (hasOffer)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: RoomPromoBadge(tag: offerText),
            ),
          if (!data.isAvailable) const RoomBookedOverlay(),
        ],
      ),
    );
  }
}
