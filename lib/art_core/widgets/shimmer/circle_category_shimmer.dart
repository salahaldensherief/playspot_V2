import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class CircleCategoryShimmer extends StatelessWidget {
  const CircleCategoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) => SizedBox(width: 16.w),
        itemBuilder: (context, index) {
          return Column(
            children: [
              BaseShimmer(
                width: 60.w,
                height: 60.w,
                borderRadius: 30.r,
              ),
              SizedBox(height: 8.h),
              BaseShimmer(
                width: 40.w,
                height: 10.h,
                borderRadius: 4.r,
              ),
            ],
          );
        },
      ),
    );
  }
}
