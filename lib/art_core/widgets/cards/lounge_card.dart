import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/lounge_helper.dart';
import 'package:playspot/art_core/widgets/lounge/lounge_category_icon.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';
import '../layout/glass_container.dart';
import '../lounge/lounge_favorite_button.dart';
import '../lounge/lounge_status_badge.dart';
import '../../../features/home/data/models/lounge_model.dart';

class LoungeCard extends StatefulWidget {
  final LoungeModel lounge;
  final VoidCallback? onTap;
  final String? heroTag;

  const LoungeCard({super.key, required this.lounge, this.onTap, this.heroTag});

  @override
  State<LoungeCard> createState() => _LoungeCardState();
}

class _LoungeCardState extends State<LoungeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final lounge = widget.lounge;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.r16),
            border: lounge.isDiscountActive
                ? Border.all(
                    color: AppColors.withOpacity(AppColors.warning, 0.5),
                    width: 1.5,
                  )
                : Border.all(
                    color: AppColors.withOpacity(AppColors.neonBlue, 0.2),
                    width: 1,
                  ),
            boxShadow: lounge.isDiscountActive
                ? [
                    BoxShadow(
                      color: AppColors.withOpacity(AppColors.warning, 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: AppColors.withOpacity(Colors.black, 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.r16),
            child: Stack(
              children: [
                // 1. Full-Cover Image
                Positioned.fill(
                  child: Hero(
                    tag: widget.heroTag ?? 'lounge_image_${lounge.id}',
                    child: CachedNetworkImage(
                      imageUrl: "${lounge.imageUrl}?width=400&quality=80",
                      fit: BoxFit.cover,
                      memCacheHeight: 400,
                      placeholder: (context, url) => Container(
                        color: AppColors.mutedBackground,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.mutedBackground,
                        child: const Icon(Icons.error_outline),
                      ),
                    ),
                  ),
                ),

                // 2. Gradient Overlay for readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.withOpacity(Colors.black, 0.25),
                          Colors.transparent,
                          AppColors.withOpacity(Colors.black, 0.55),
                          AppColors.withOpacity(Colors.black, 0.92),
                        ],
                        stops: const [0.0, 0.25, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Top Badges
                // Favorite Button (Top Start)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: AppSizes.s8,
                  start: AppSizes.w8,
                  child: LoungeFavoriteButton(loungeId: lounge.id),
                ),

                // Status Badge (Top End)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: AppSizes.s8,
                  end: AppSizes.w8,
                  child: LoungeStatusBadge(isOpen: lounge.isOpen),
                ),

                // Discount Badge (below Favorite)
                if (lounge.isDiscountActive)
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 38.h,
                    start: AppSizes.w8,
                    child: _buildDiscountBadge(context),
                  ),

                // 4. Floating Glass Details Panel at Bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GlassContainer(
                    borderRadius: AppSizes.r16,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 5.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          AppText(
                            text: lounge.name,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          2.verticalSpace,
                          // Rating & Combined Location/Distance Row
                          _buildRatingAndLocation(),
                          4.verticalSpace,
                          // Amenities HUD & Price Pill
                          _buildAmenitiesAndPrice(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountBadge(BuildContext context) {
    final lounge = widget.lounge;
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.warning, Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.r6),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(Colors.black, 0.4),
            blurRadius: 4,
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
            fontSize: 8.sp,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
          2.horizontalSpace,
          Text("🔥", style: TextStyle(fontSize: 8.sp)),
        ],
      ),
    );
  }

  Widget _buildRatingAndLocation() {
    final lounge = widget.lounge;
    final isArabic = context.locale.languageCode == 'ar';

    final String ratingDisplay = lounge.rating > 0
        ? lounge.rating.toStringAsFixed(1)
        : "--";

    final String locationText = (lounge.city != null && lounge.city!.isNotEmpty)
        ? lounge.city!
        : (lounge.location ?? '');

    final String distanceText = lounge.getFormattedDistance(isArabic: isArabic);

    return Row(
      children: [
        // Star Rating
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: AppColors.warning, size: 12.sp),
            2.horizontalSpace,
            AppText(
              text: ratingDisplay,
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ],
        ),
        4.horizontalSpace,
        // Location (City/Address) + Distance in Expanded Row
        if (locationText.isNotEmpty || distanceText.isNotEmpty)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.neonBlue,
                  size: 11.sp,
                ),
                2.horizontalSpace,
                if (locationText.isNotEmpty) ...[
                  Flexible(
                    child: AppText(
                      text: locationText,
                      fontSize: 9.sp,
                      color: AppColors.withOpacity(AppColors.white, 0.8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  if (distanceText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      child: AppText(
                        text: "•",
                        fontSize: 8.sp,
                        color: AppColors.withOpacity(AppColors.white, 0.4),
                      ),
                    ),
                ],
                if (distanceText.isNotEmpty)
                  AppText(
                    text: distanceText,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonBlue,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAmenitiesAndPrice() {
    final lounge = widget.lounge;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category Icons
        Row(
          children: [
            if (lounge.categoryIcons.isNotEmpty)
              ...lounge.categoryIcons
                  .take(3)
                  .map((iconKey) => LoungeCategoryIcon(
                        icon: LoungeHelper.getIconFromKey(iconKey),
                      ))
            else ...[
              const LoungeCategoryIcon(icon: Icons.videogame_asset_outlined),
              const LoungeCategoryIcon(icon: Icons.computer_outlined),
            ],
          ],
        ),
        // Price Tag Pill
        _buildPriceInfo(),
      ],
    );
  }

  Widget _buildPriceInfo() {
    final lounge = widget.lounge;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.withOpacity(AppColors.neonBlue, 0.18),
        borderRadius: BorderRadius.circular(AppSizes.r6),
        border: Border.all(
          color: AppColors.withOpacity(AppColors.neonBlue, 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            text: "${AppStrings.from.tr()} ",
            fontSize: 7.sp,
            color: AppColors.withOpacity(AppColors.white, 0.7),
          ),
          AppText(
            text: "${lounge.pricePerHour.toInt()}",
            fontSize: 11.sp,
            fontWeight: FontWeight.w900,
            color: AppColors.neonBlue,
          ),
          AppText(
            text: " ${AppStrings.egp.tr()}",
            fontSize: 7.sp,
            color: AppColors.neonBlue,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}
