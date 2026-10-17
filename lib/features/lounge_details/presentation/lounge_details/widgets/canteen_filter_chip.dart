import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class CanteenFilterChip extends StatelessWidget {
  const CanteenFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    backgroundColor: AppColors.cardBackground,
    selectedColor: AppColors.primary.withValues(alpha: .12),
    labelStyle: TextStyle(
      color: selected ? AppColors.primary : AppColors.textSecondary,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
    side: BorderSide(
      color: (selected ? AppColors.primary : AppColors.textSecondary)
          .withValues(alpha: selected ? .5 : .2),
    ),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}
