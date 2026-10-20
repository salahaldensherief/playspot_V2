import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungeOperatingHours extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeOperatingHours({super.key, required this.lounge});

  TimeOfDay? _time(String source) {
    final parts = source.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final start = _time(lounge.openingTime);
    final end = _time(lounge.closingTime);
    if (start == null || end == null) return const SizedBox.shrink();
    final overnight =
        end.hour * 60 + end.minute < start.hour * 60 + start.minute;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.schedule_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            text: (overnight ? 'lounge_hours_overnight' : 'lounge_hours').tr(
              namedArgs: {
                'start': start.format(context),
                'end': end.format(context),
              },
            ),
          ),
        ),
      ],
    );
  }
}
