import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class RoomPromoBadge extends StatelessWidget {
  final String tag;
  const RoomPromoBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tag,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(18),
          bottomEnd: Radius.circular(8),
        ),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
    ),
  );
}
