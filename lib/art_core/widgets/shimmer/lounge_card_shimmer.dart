import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class LoungeCardShimmer extends StatelessWidget {
  const LoungeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.w,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseShimmer(
            width: double.infinity,
            height: 140.h,
            borderRadius: 20.r,
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseShimmer(width: 150.w, height: 16.h),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    BaseShimmer(width: 40.w, height: 12.h),
                    SizedBox(width: 12.w),
                    BaseShimmer(width: 60.w, height: 12.h),
                  ],
                ),
                SizedBox(height: 16.h),
                BaseShimmer(width: 100.w, height: 20.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
