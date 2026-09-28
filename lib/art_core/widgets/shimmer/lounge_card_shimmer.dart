import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class LoungeCardShimmer extends StatelessWidget {
  const LoungeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseShimmer(
            width: double.infinity,
            height: 110.h,
            borderRadius: 16.r,
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseShimmer(width: 110.w, height: 13.h),
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BaseShimmer(width: 35.w, height: 10.h),
                    BaseShimmer(width: 50.w, height: 10.h),
                  ],
                ),
                SizedBox(height: 6.h),
                BaseShimmer(width: 70.w, height: 14.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
