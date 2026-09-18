import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../data/models/promo_model.dart';

class PromoCard extends StatelessWidget {
  final PromoModel promo;
  final VoidCallback? onTap;

  const PromoCard({super.key, required this.promo, this.onTap});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    final isArabic = context.locale.languageCode == 'ar';
    final hasImage = promo.imageUrl != null && promo.imageUrl!.trim().isNotEmpty;
    final tag = promo.getTag(isArabic);
    final title = promo.getTitle(isArabic);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: 2.horizontalPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.r24),
          gradient: LinearGradient(
            colors: promo.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            if (hasImage) ...[
              // Background Image when image_url is available
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                  child: CachedNetworkImage(
                    imageUrl: promo.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: promo.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: AppLoader(size: 28, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: promo.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20.w,
                            bottom: -20.h,
                            child: Icon(
                              promo.icon,
                              size: 150.sp,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Dark Vignette Overlay for readable text over image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.r24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Fallback color template with icon background when image_url is null
              Positioned(
                right: -20.w,
                bottom: -20.h,
                child: Icon(
                  promo.icon,
                  size: 150.sp,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ],
            // Content: Tag and Title
            Padding(
              padding: 20.allPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tag.isNotEmpty) ...[
                    Container(
                      padding: 8.horizontalPadding + 4.verticalPadding,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppSizes.r8),
                      ),
                      child: AppText(
                        text: tag.toUpperCase(),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    8.verticalSpace,
                  ],
                  if (title.isNotEmpty)
                    AppText(
                      text: title,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
