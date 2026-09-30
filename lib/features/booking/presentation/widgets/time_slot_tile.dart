import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class TimeSlotTile extends StatelessWidget {
  final String timeLabel;
  final bool booked;
  final bool selected;
  final bool inRange;
  final bool peak;
  final bool waitlisted;
  final double? hourlyRate;
  final VoidCallback onTap;
  const TimeSlotTile({
    super.key,
    required this.timeLabel,
    required this.booked,
    required this.selected,
    required this.inRange,
    required this.peak,
    required this.waitlisted,
    this.hourlyRate,
    required this.onTap,
  });
  Color get _accent => booked
      ? AppColors.danger
      : peak
      ? AppColors.warning
      : AppColors.neonBlue;
  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.black : AppColors.white;
    final status = booked
        ? (waitlisted ? AppStrings.notifyMe.tr() : AppStrings.booked.tr())
        : selected
        ? 'slot_selected'.tr()
        : peak
        ? AppStrings.peak.tr()
        : AppStrings.available.tr();
    return Semantics(
      button: true,
      selected: selected,
      label: '$timeLabel, $status',
      child: AppButton(
        behavior: ButtonBehavior.tap(onTap: onTap),
        buttonConfig: ButtonConfig(
          width: 116,
          height: MediaQuery.textScalerOf(context).scale(128),
          borderRadius: 14,
          padding: const EdgeInsets.all(8),
          backgroundColor: selected
              ? AppColors.neonBlue
              : _accent.withValues(alpha: inRange ? 0.2 : 0.08),
          borderColor: selected
              ? AppColors.white
              : _accent.withValues(alpha: 0.5),
        ),
        content: ButtonContent(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : booked
                    ? Icons.notifications_none_rounded
                    : Icons.schedule_rounded,
                size: 18,
                color: selected ? foreground : _accent,
              ),
              const SizedBox(height: 6),
              AppText(
                text: timeLabel,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: foreground,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (!booked && hourlyRate != null)
                AppText(
                  text:
                      '${hourlyRate?.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()} / ${AppStrings.perHour.tr()}',
                  fontSize: 10,
                  color: foreground,
                  textAlign: TextAlign.center,
                ),
              AppText(
                text: status,
                fontSize: 10,
                color: selected ? foreground : _accent,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
