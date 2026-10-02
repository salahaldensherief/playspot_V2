import '../../room_card_presentation.dart';
import 'room_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_constants.dart';
import 'room_features_details.dart';
import 'room_activities_details.dart';
import 'room_gallery_button.dart';
import 'room_selection_configuration.dart';

class RoomExpandedDetails extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isExpanded;
  final RoomCardPresentation data;
  Color get themeColor => room.themeColor;
  const RoomExpandedDetails({
    super.key,
    required this.room,
    required this.isArabic,
    required this.isExpanded,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final features = room.getFeatures(isArabic);
    final configuration =
        data.isSelected && (room.isOpenArea || room.extraControllerPrice > 0);
    final sections = <Widget>[
      if (configuration)
        RoomSelectionConfiguration(room: room, themeColor: themeColor),
      if (features.isNotEmpty)
        RoomFeaturesDetails(features: features, color: themeColor),
      if (room.activityNames.isNotEmpty)
        RoomActivitiesDetails(
          activities: room.activityNames,
          color: themeColor,
        ),
      if (room.images.isNotEmpty)
        RoomGalleryButton(room: room, themeColor: themeColor),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(color: Colors.white12),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: section,
              ),
          ],
        ),
      ),
      crossFadeState: isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: RoomConstants.animationDuration,
    );
  }
}
