import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class RoomSpec extends StatelessWidget {
  final IconData icon;
  final String value;
  const RoomSpec({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
