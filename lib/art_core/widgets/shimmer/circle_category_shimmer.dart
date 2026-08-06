import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'base_shimmer.dart';

class CircleCategoryShimmer extends StatelessWidget {
  const CircleCategoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          return BaseShimmer(
            width: 80.w,
            height: 75.h,
            borderRadius: AppSizes.r20,
          );
        },
      ),
    );
  }
}
