import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/services/directions_service.dart';

/// Reusable Directions button for opening navigation to lounges, bookings, or tournaments.
/// Prioritizes [lat] and [lng] coordinates and falls back to [mapsLink] or location search.
class DirectionsButton extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String? loungeName;
  final String? loungeLocation;
  final String? mapsLink;
  final double? height;
  final double? width;
  final bool isFullWidth;
  final bool isPrimary;
  final VoidCallback? onBeforeLaunch;

  const DirectionsButton({
    super.key,
    this.lat,
    this.lng,
    this.loungeName,
    this.loungeLocation,
    this.mapsLink,
    this.height,
    this.width,
    this.isFullWidth = false,
    this.isPrimary = false,
    this.onBeforeLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isPrimary ? AppColors.black : AppColors.neonBlue;

    return AppButton(
      content: ButtonContent(
        label: AppStrings.getDirections.tr(),
        icon: Icon(Icons.directions, size: 18.sp, color: iconColor),
      ),
      behavior: ButtonBehavior.tap(
        onTap: () async {
          if (onBeforeLaunch != null) {
            onBeforeLaunch!();
          }
          final success = await GetIt.instance<DirectionsService>().openDirections(
            lat: lat,
            lng: lng,
            loungeName: loungeName,
            loungeLocation: loungeLocation,
            mapsLink: mapsLink,
          );

          if (!success && context.mounted) {
            GameHudToast.show(
              context,
              AppStrings.somethingWentWrong.tr(),
              type: ToastType.error,
            );
          }
        },
      ),
      buttonConfig: ButtonConfig(
        height: height ?? 40.h,
        width: isFullWidth ? double.infinity : width,
        backgroundColor: isPrimary
            ? AppColors.neonBlue
            : AppColors.neonBlue.withValues(alpha: 0.12),
        borderColor: isPrimary ? null : AppColors.neonBlue.withValues(alpha: 0.5),
        isOutlined: !isPrimary,
        borderRadius: 12.r,
        textStyle: TextStyle(
          color: isPrimary ? AppColors.black : AppColors.neonBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}
