import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'room_action_area.dart';
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
  final String availabilityLabel;

  const RoomMainContent({
    super.key,
    required this.room,
    required this.isArabic,
    required this.isAvailable,
    required this.isSelected,
    required this.isExpanded,
    required this.themeColor,
    required this.availabilityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final lounge = context.select(
      (LoungeDetailsCubit cubit) => cubit.state.lounge,
    );
    final bool hasLoungeOffer =
        lounge != null &&
        lounge.isDiscountActive &&
        lounge.discountPercentage > 0;
    final bool hasOffer = room.hasActivePromo || hasLoungeOffer;

    final verticalPadding = hasOffer ? 18.h : 12.h;
    final horizontalPadding = 14.w;

    String offerTag = AppStrings.activeOffer.tr();
    if (room.hasActivePromo) {
      offerTag = room.getPromoTag(isArabic) ?? AppStrings.activeOffer.tr();
    } else if (hasLoungeOffer) {
      offerTag =
          lounge.getDiscountTitle(isArabic) ??
          "${AppStrings.discount.tr()} ${lounge.discountPercentage}%";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      availabilityLabel.tr(),
                      style: TextStyle(
                        color: isAvailable ? themeColor : Colors.white70,
                      ),
                    ),
                  ),
                  if (hasOffer) RoomPromoBadge(tag: offerTag),
                ],
              ),
              const SizedBox(height: 12),
              RoomHeader(
                room: room,
                isArabic: isArabic,
                isAvailable: isAvailable,
                isExpanded: isExpanded,
                themeColor: themeColor,
              ),
              const SizedBox(height: 10),
              RoomSpaceTypeBadge(
                room: room,
                isArabic: isArabic,
                themeColor: themeColor,
              ),
              const SizedBox(height: 8),
              RoomQuickSpecs(room: room),
            ],
          ),
        ),
        if (isAvailable)
          Divider(height: 1, color: themeColor.withValues(alpha: 0.16)),
        RoomActionArea(
          room: room,
          isAvailable: isAvailable,
          isSelected: isSelected,
          themeColor: themeColor,
        ),
      ],
    );
  }
}
