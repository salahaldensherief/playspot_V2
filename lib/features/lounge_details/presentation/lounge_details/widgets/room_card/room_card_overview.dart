import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../room_card_presentation.dart';
import 'room_header.dart';
import 'room_promo_badge.dart';
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

  String _offer(bool arabic) => room.hasActivePromo
      ? room.getPromoTag(arabic) ?? AppStrings.activeOffer.tr()
      : data.lounge?.getDiscountTitle(arabic) ??
            '${AppStrings.discount.tr()} ${data.lounge?.discountPercentage ?? 0}%';

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomHeader(
            room: room,
            isArabic: arabic,
            isAvailable: data.isAvailable,
            isExpanded: expanded,
            themeColor: room.themeColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: room.themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  data.availabilityKey.tr(),
                  style: TextStyle(
                    color: data.isAvailable ? room.themeColor : Colors.white70,
                  ),
                ),
              ),
              if (data.hasOffer(room)) RoomPromoBadge(tag: _offer(arabic)),
              RoomSpaceTypeBadge(
                room: room,
                isArabic: arabic,
                themeColor: room.themeColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RoomQuickSpecs(room: room),
        ],
      ),
    );
  }
}
