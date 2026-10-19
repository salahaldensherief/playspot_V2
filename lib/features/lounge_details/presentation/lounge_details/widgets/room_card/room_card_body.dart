import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import '../../room_card_presentation.dart';
import 'room_constants.dart';
import 'room_expanded_details.dart';
import 'room_main_content.dart';
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
  Widget build(BuildContext context) {
    final previewImage = room.images
        .where((image) => image.trim().isNotEmpty)
        .firstOrNull;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: RoomConstants.animationDuration,
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(RoomConstants.borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previewImage != null)
                SizedBox(
                  width: double.infinity,
                  height: 112,
                  child: AppImage(
                    urlImg: previewImage,
                    fit: BoxFit.cover,
                    borderRadius: 0,
                    placeholderWidget: Container(
                      color: room.themeColor.withValues(alpha: .12),
                    ),
                    errorWidget: Container(
                      color: room.themeColor.withValues(alpha: .12),
                      child: Icon(room.icon, color: room.themeColor, size: 32),
                    ),
                  ),
                )
              else
                Container(height: 4, color: room.themeColor),
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
      ),
    );
  }
}
