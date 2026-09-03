import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import '../../app_strings.dart';
import '../../router/router_keys.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';
import '../../../features/home/data/models/lounge_model.dart';

class SearchLoungeCard extends StatelessWidget {
  final LoungeModel lounge;
  const SearchLoungeCard({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final heroTag = 'lounge_${lounge.id}_search';
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          RouterKeys.loungeDetails,
          extra: {
            'lounge': lounge,
            'heroTag': heroTag,
          },
        );
      },
      child: Container(
        padding: 8.allPadding,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(
            color: lounge.isDiscountActive
                ? AppColors.withOpacity(AppColors.warning, 0.4)
                : AppColors.borderDefault,
            width: lounge.isDiscountActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.r15),
                  child: Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: lounge.imageUrl,
                      width: 140.w,
                      height: 140.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (lounge.isDiscountActive)
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: _buildDiscountBadge(context),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: 16.horizontalPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: lounge.name,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppText(
                      text: lounge.location ?? "",
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: AppColors.warning, size: 16.sp),
                        4.horizontalSpace,
                        AppText(
                          text: lounge.rating.toString(),
                          fontSize: 12.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        12.horizontalSpace,
                        Icon(Icons.location_on_outlined,
                            color: AppColors.textSecondary, size: 16.sp),
                        4.horizontalSpace,
                        Expanded(
                          child: AppText(
                            text: "${lounge.distance.toStringAsFixed(1)} ${AppStrings.km.tr()}",
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    12.verticalSpace,
                    _buildPriceInfo(),
                    4.verticalSpace,
                    AppText(
                      text:
                          "${lounge.availableRooms} ${AppStrings.ps5RoomsAvailable.tr()}",
                      fontSize: 10.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountBadge(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.black, 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppText(
        text: lounge.getDiscountTitle(isArabic) ??
            "${AppStrings.discount.tr()} ${lounge.discountPercentage}%",
        fontSize: 8.sp,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
    );
  }

  Widget _buildPriceInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        AppText(
          text: "${lounge.pricePerHour.toInt()} ${AppStrings.egp.tr()}",
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.neonBlue,
        ),
        4.horizontalSpace,
        AppText(
          text: AppStrings.perHour.tr(),
          fontSize: 12.sp,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}
