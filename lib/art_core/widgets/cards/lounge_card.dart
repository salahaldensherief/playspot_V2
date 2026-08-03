import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      child: GlassContainer(
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Main Image
                ClipRRect(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24.r)),
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
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: LoungeStatusBadge(isOpen: lounge.isOpen),
                ),

                // Favorite Toggle
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: LoungeFavoriteButton(loungeId: lounge.id),
                ),

                // Distance Badge
                if (lounge.distance > 0)
                  Positioned(
                    bottom: 8.h,
                    right: 8.w,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: AppColors.neonBlue, size: 12.sp),
                          SizedBox(width: 4.w),
                          AppText(
                            text: "${lounge.distance.toStringAsFixed(1)} km",
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(12.w),
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
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: AppColors.warning, size: 16.sp),
                      SizedBox(width: 4.w),
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
                            color: AppColors.neonBlue.withValues(alpha: 0.7),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildAmenitiesHud(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesHud() {
    return Row(
      children: [
        _hudIcon(Icons.videogame_asset_outlined),
        _hudIcon(Icons.computer_outlined),
        _hudIcon(Icons.fastfood_outlined),
        const Spacer(),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppText(
                text: "FROM ",
                fontSize: 8.sp,
                color: AppColors.textSecondary,
              ),
              Flexible(
                child: AppText(
                  text: "${lounge.pricePerHour.toInt()} EGP",
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonBlue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hudIcon(IconData icon) {
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Icon(icon, size: 14.sp, color: AppColors.textSecondary),
      ),
    );
  }
}
