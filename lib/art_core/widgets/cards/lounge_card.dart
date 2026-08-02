import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';
import '../layout/glass_container.dart';
import '../../../features/home/data/models/lounge_model.dart';
import '../../../features/favorites/presentation/favorites_cubit.dart';
import '../../../features/favorites/presentation/favorites_state.dart';

class LoungeCard extends StatelessWidget {
  final LoungeModel lounge;
  final VoidCallback? onTap;

  const LoungeCard({super.key, required this.lounge, this.onTap});

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

                // Open/Closed Badge with Neon Glow
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: _buildStatusBadge(),
                ),

                // Favorite Toggle
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: _buildFavoriteButton(),
                ),

                // Distance Badge (Floating over image)
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

  Widget _buildStatusBadge() {
    final color = lounge.isOpen ? AppColors.success : AppColors.roomBooked;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          AppText(
            text: lounge.isOpen ? "ACTIVE" : "CLOSED",
            fontSize: 9.sp,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, state) {
        final isFavorite = context.read<FavoritesCubit>().isFavorite(lounge.id);
        return GestureDetector(
          onTap: () => context.read<FavoritesCubit>().toggleFavorite(lounge.id),
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.danger : AppColors.white,
              size: 18.sp,
            ),
          ),
        );
      },
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
