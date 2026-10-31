import 'package:flutter/material.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class RoomSectionHeader extends StatelessWidget {
  final String title;
  final Color themeColor;
  const RoomSectionHeader({
    super.key,
    required this.title,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppText(
      text: title.toUpperCase(),
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: themeColor.withValues(alpha: 0.7),
      letterSpacing: 0.8,
    );
  }
}
