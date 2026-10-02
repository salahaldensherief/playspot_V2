import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'app_button.dart';
import 'directions_button.dart';
import 'res/button_behavior.dart';
import 'res/button_content.dart';
import 'res/button_style_config.dart';

class DirectionsButtonContent extends StatelessWidget {
  final DirectionsButton button;
  final bool launching;
  final VoidCallback onTap;
  const DirectionsButtonContent({
    super.key,
    required this.button,
    required this.launching,
    required this.onTap,
  });

  Color get foreground =>
      button.isPrimary ? AppColors.black : AppColors.neonBlue;

  @override
  Widget build(BuildContext context) => AppButton(
    content: ButtonContent(
      label: AppStrings.getDirections.tr(),
      icon: Icon(Icons.directions, size: 20, color: foreground),
    ),
    behavior: ButtonBehavior.tap(onTap: onTap, isLoading: launching),
    buttonConfig: _config(context),
  );

  ButtonConfig _config(BuildContext context) => ButtonConfig(
    height:
        (button.height ?? 48).clamp(48.0, double.infinity) *
        MediaQuery.textScalerOf(context).scale(1),
    width: button.isFullWidth ? double.infinity : button.width,
    backgroundColor: button.isPrimary
        ? AppColors.neonBlue
        : AppColors.neonBlue.withValues(alpha: 0.12),
    borderColor: button.isPrimary
        ? null
        : AppColors.neonBlue.withValues(alpha: 0.5),
    isOutlined: !button.isPrimary,
    borderRadius: 12,
    textStyle: TextStyle(
      color: foreground,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    ),
  );
}
