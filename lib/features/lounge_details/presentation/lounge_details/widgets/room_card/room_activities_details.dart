import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'room_detail_chip.dart';
import 'room_section_header.dart';

class RoomActivitiesDetails extends StatelessWidget {
  final List<String> activities;
  final Color color;
  const RoomActivitiesDetails({
    super.key,
    required this.activities,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RoomSectionHeader(title: 'room_activities'.tr(), themeColor: color),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: activities
            .map((a) => RoomDetailChip(label: a, themeColor: color))
            .toList(),
      ),
    ],
  );
}
