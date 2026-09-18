import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import '../../app_strings.dart';
import '../../router/router_keys.dart';
import '../../theme/app_colors.dart';
import '../images/app_images.dart';
import '../text/app_text.dart';
import '../../../features/home/data/models/lounge_model.dart';

class SearchLoungeCard extends StatelessWidget {
  final LoungeModel lounge;
  const SearchLoungeCard({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
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
            color: AppColors.borderDefault,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: heroTag,
                  child: AppImage(
                    urlImg: lounge.imageUrl,
                    width: 130.w,
                    height: 130.h,
                    fit: BoxFit.cover,
                    borderRadius: AppSizes.r15,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        AppText(
                          text: lounge.location ?? "",
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        6.verticalSpace,
                        Row(
                          children: [
                            Icon(Icons.star, color: AppColors.warning, size: 14.sp),
                            4.horizontalSpace,
                            AppText(
                              text: lounge.rating > 0 ? lounge.rating.toStringAsFixed(1) : "N/A",
                              fontSize: 11.sp,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            8.horizontalSpace,
                            Icon(Icons.location_on_outlined,
                                color: AppColors.textSecondary, size: 14.sp),
                            4.horizontalSpace,
                            Expanded(
                              child: AppText(
                                text: "${lounge.distance.toStringAsFixed(1)} ${AppStrings.km.tr()}",
                                fontSize: 11.sp,
                                color: AppColors.textSecondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        8.verticalSpace,
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildPriceInfo(),
                        ),
                        4.verticalSpace,
                        AppText(
                          text:
                              "${lounge.availableRooms} ${AppStrings.ps5RoomsAvailable.tr()}",
                          fontSize: 10.sp,
                          color: AppColors.textSecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (lounge.isDiscountActive)
              Positioned(
                top: 0,
                right: 0,
                child: _buildDiscountBadge(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountBadge(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final text = lounge.getDiscountTitle(isArabic) ??
        "-${lounge.discountPercentage}%";

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppSizes.r20),
          bottomLeft: Radius.circular(10.r),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.black, 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppText(
        text: text,
        fontSize: 9.sp,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
    );
  }

  Widget _buildPriceInfo() {
    final bool hasDiscount = lounge.isDiscountActive && lounge.discountPercentage > 0;
    final double discountedPrice = hasDiscount
        ? lounge.pricePerHour * (1 - (lounge.discountPercentage / 100))
        : lounge.pricePerHour;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (hasDiscount) ...[
          Text(
            "${lounge.pricePerHour.toInt()} ${AppStrings.egp.tr()}",
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          4.horizontalSpace,
        ],
        AppText(
          text: "${discountedPrice.toInt()} ${AppStrings.egp.tr()}",
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: hasDiscount ? AppColors.success : AppColors.neonBlue,
        ),
        4.horizontalSpace,
        AppText(
          text: AppStrings.perHour.tr(),
          fontSize: 11.sp,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}
