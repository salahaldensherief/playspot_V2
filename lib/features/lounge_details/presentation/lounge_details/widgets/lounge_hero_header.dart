import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/utils/extensions/date_time_extensions.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungeHeroHeader extends StatelessWidget {
  final LoungeModel lounge;
  final String heroTag;
  const LoungeHeroHeader({
    super.key,
    required this.lounge,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (lounge.galleryImages.isNotEmpty)
        Hero(
          tag: heroTag,
          child: AppImage(
            urlImg: lounge.galleryImages.first,
            fit: BoxFit.cover,
            borderRadius: 0,
          ),
        ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black26,
              AppColors.scaffoldBackground.withValues(alpha: 0.9),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: lounge.name,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                if ((lounge.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AppText(
                    text: lounge.location!,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ],
                const SizedBox(height: 6),
                AppText(
                  text:
                      '${AppStrings.openHours.tr()} ${lounge.opensAt.toAppTimeString(locale: context.locale.languageCode)} – ${lounge.closesAt.toAppTimeString(locale: context.locale.languageCode)}',
                  fontSize: 13,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
