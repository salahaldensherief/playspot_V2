import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
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
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          RouterKeys.loungeDetails,
          extra: lounge,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15.r),
              child: Hero(
                tag: 'lounge_image_${lounge.id}',
                child: CachedNetworkImage(
                  imageUrl: lounge.imageUrl,
                  width: 140.w,
                  height: 140.h,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                        SizedBox(width: 4.w),
                        AppText(
                          text: lounge.rating.toString(),
                          fontSize: 12.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        SizedBox(width: 12.w),
                        Icon(Icons.location_on_outlined,
                            color: AppColors.textSecondary, size: 16.sp),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: AppText(
                            text: "${lounge.distance} ${AppStrings.km.tr()}",
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                "${lounge.pricePerHour.toInt()} ${AppStrings.egp.tr()}",
                            style: TextStyle(
                              color: AppColors.neonBlue,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Orbitron",
                            ),
                          ),
                          TextSpan(
                            text: AppStrings.perHour.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4.h),
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
}
