import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
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
      child: Container(

        width: 250.w,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.r),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: lounge.imageUrl,
                    height: 140.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.mutedBackground,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.mutedBackground,
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),

                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: BlocBuilder<FavoritesCubit, FavoritesState>(
                    builder: (context, state) {
                      final isFavorite = context
                          .read<FavoritesCubit>()
                          .isFavorite(lounge.id);
                      return GestureDetector(
                        onTap: () => context
                            .read<FavoritesCubit>()
                            .toggleFavorite(lounge.id),
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: AppColors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? AppColors.danger
                                : AppColors.white,
                            size: 20.sp,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: (lounge.isOpen ? AppColors.successBackground : AppColors.roomBooked).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: lounge.isOpen ? AppColors.successBorder : AppColors.roomBooked),
                    ),
                    child: AppText(
                      text: lounge.isOpen ? "Open" : "Closed",
                      fontSize: 10.sp,
                      color: lounge.isOpen ? AppColors.success : AppColors.roomBooked,
                      fontWeight: FontWeight.w600,
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
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      SvgIconWidget(
                        path: AssetsManager.star,
                        color: AppColors.warning,
                        width: 14.w,
                        height: 14,
                      ),
                      SizedBox(width: 4.w),
                      AppText(
                        text: lounge.rating.toString(),
                        fontSize: 12.sp,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 12.w),
                      if (lounge.distance > 0) ...[
                        SvgIconWidget(
                          path: AssetsManager.locationIcon,
                          width: 14.w,
                          height: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        AppText(
                          text: "${lounge.distance.toStringAsFixed(1)} km",
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
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
