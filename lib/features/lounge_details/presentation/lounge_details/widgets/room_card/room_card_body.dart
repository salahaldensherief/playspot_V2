import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../room_card_presentation.dart';
import 'room_constants.dart';
import 'room_main_content.dart';
import 'room_expanded_details.dart';
import 'room_theme_extension.dart';

class RoomCardBody extends StatelessWidget {
  final RoomModel room;
  final RoomCardPresentation data;
  final bool expanded;
  final VoidCallback onToggle;
  const RoomCardBody({
    super.key,
    required this.room,
    required this.data,
    required this.expanded,
    required this.onToggle,
  });

  Color get borderColor => data.isSelected
      ? room.themeColor
      : data.hasOffer(room)
      ? AppColors.warning.withValues(alpha: 0.4)
      : data.isAvailable
      ? room.themeColor.withValues(alpha: 0.45)
      : AppColors.danger.withValues(alpha: 0.4);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: AnimatedContainer(
      duration: RoomConstants.animationDuration,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: data.isSelected ? 1.5 : 1),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(room.themeColor.withValues(alpha: data.isSelected ? 0.15 : 0.07), const Color(0xFF161622)),
            const Color(0xFF11111B),
          ],
        ),
      ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoomMainContent(room: room, data: data, expanded: expanded),
            RoomExpandedDetails(
              room: room,
              isArabic: context.locale.languageCode == 'ar',
              isExpanded: expanded,
              data: data,
            ),
          ],
        ),
    ),
  );
}
