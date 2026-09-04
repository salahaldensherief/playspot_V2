import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/utils/lounge_helper.dart';
import 'package:playspot/art_core/widgets/lounge/lounge_category_icon.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';
import '../layout/glass_container.dart';
import '../lounge/lounge_favorite_button.dart';
import '../lounge/lounge_status_badge.dart';
import '../../../features/home/data/models/lounge_model.dart';

class LoungeCard extends StatelessWidget {
  final LoungeModel lounge;
  final VoidCallback? onTap;
  final String? heroTag;

  const LoungeCard({super.key, required this.lounge, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.r24),
          border: lounge.isDiscountActive
              ? Border.all(color: AppColors.warning.withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: lounge.isDiscountActive
              ? [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: GlassContainer(
          borderRadius: AppSizes.r24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(context),
              _buildDetailsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Stack(
      children: [
        // Main Image
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
          child: Hero(
            tag: heroTag ?? 'lounge_image_${lounge.id}',
            child: CachedNetworkImage(
              imageUrl: "${lounge.imageUrl}?width=400&quality=80",
              height: 130.h,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheHeight: 400,
              placeholder: (context, url) => Container(
                color: AppColors.mutedBackground,
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.mutedBackground,
                child: const Icon(Icons.error),
              ),
            ),
          ),
        ),

        // Open/Closed Badge
        Positioned.directional(
          textDirection: Directionality.of(context),
          top: AppSizes.s12,
          end: AppSizes.w12,
          child: LoungeStatusBadge(isOpen: lounge.isOpen),
        ),

        // Favorite Toggle
        Positioned.directional(
          textDirection: Directionality.of(context),
          top: AppSizes.s12,
          start: AppSizes.w12,
          child: LoungeFavoriteButton(loungeId: lounge.id),
        ),

        // Discount Badge
        if (lounge.isDiscountActive)
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: 45.h,
            start: AppSizes.w12,
            child: _buildDiscountBadge(context),
          ),

        // Distance Badge
        if (lounge.distance > 0 && lounge.distance < 99999)
          Positioned.directional(
            textDirection: Directionality.of(context),
            bottom: AppSizes.s8,
            end: AppSizes.w8,
            child: _buildDistanceBadge(),
          ),
      ],
    );
  }

  Widget _buildDiscountBadge(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      padding: 10.horizontalPadding + 4.verticalPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.warning, Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.r10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            text: lounge.getDiscountTitle(isArabic) ??
                "${AppStrings.discount.tr()} ${lounge.discountPercentage}%",
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
          4.horizontalSpace,
          Text("🔥", style: TextStyle(fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _buildDistanceBadge() {
    return Container(
      padding: 8.horizontalPadding + 4.verticalPadding,
      decoration: BoxDecoration(
        color: AppColors.blackOverlay,
        borderRadius: BorderRadius.circular(AppSizes.r10),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: AppColors.neonBlue, size: 12.sp),
          4.horizontalSpace,
          AppText(
            text: "${lounge.distance.toStringAsFixed(1)} ${AppStrings.km.tr()}",
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: 12.allPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: lounge.name,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          4.verticalSpace,
          _buildRatingAndCity(),
          8.verticalSpace,
          _buildAmenitiesHud(),
        ],
      ),
    );
  }

  Widget _buildRatingAndCity() {
    return Row(
      children: [
        Icon(Icons.star_rounded, color: AppColors.warning, size: 16.sp),
        4.horizontalSpace,
        AppText(
          text: lounge.rating.toString(),
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        if (lounge.totalReviews != null)
          AppText(
            text: " (${lounge.totalReviews})",
            fontSize: 10.sp,
            color: AppColors.textSecondary,
          ),
        const Spacer(),
        if (lounge.city != null)
          Flexible(
            child: AppText(
              text: lounge.city!,
              fontSize: 10.sp,
              color: AppColors.neonBlue.withOpacity(0.7),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
      ],
    );
  }

  Widget _buildAmenitiesHud() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Icons on the left
        Row(
          children: [
            if (lounge.categoryIcons.isNotEmpty)
              ...lounge.categoryIcons
                  .take(3)
                  .map((iconKey) => LoungeCategoryIcon(icon: LoungeHelper.getIconFromKey(iconKey)))
            else ...[
              const LoungeCategoryIcon(icon: Icons.videogame_asset_outlined),
              const LoungeCategoryIcon(icon: Icons.computer_outlined),
            ],
          ],
        ),
        // Price on the right
        _buildPriceInfo(),
      ],
    );
  }

  Widget _buildPriceInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          text: "${AppStrings.from.tr()} ",
          fontSize: 7.sp,
          color: AppColors.textSecondary,
        ),
        AppText(
          text: "${lounge.pricePerHour.toInt()}",
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
          color: AppColors.neonBlue,
        ),
        AppText(
          text: " ${AppStrings.egp.tr()}",
          fontSize: 8.sp,
          color: AppColors.neonBlue,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }
}
