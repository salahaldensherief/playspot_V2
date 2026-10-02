import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'room_feature_item.dart';
import 'room_section_header.dart';

class RoomFeaturesDetails extends StatelessWidget {
  final List<String> features;
  final Color color;
  const RoomFeaturesDetails({
    super.key,
    required this.features,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RoomSectionHeader(title: AppStrings.roomFeatures.tr(), themeColor: color),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: features.map((f) => RoomFeatureItem(feature: f)).toList(),
      ),
    ],
  );
}
