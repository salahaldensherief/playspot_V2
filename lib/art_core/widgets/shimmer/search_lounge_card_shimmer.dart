import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class SearchLoungeCardShimmer extends StatelessWidget {
  const SearchLoungeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseShimmer(width: 100.w, height: 100.h, borderRadius: 15.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseShimmer(width: 140.w, height: 18.h),
                SizedBox(height: 8.h),
                BaseShimmer(width: 100.w, height: 12.h),
                SizedBox(height: 12.h),
                BaseShimmer(width: 80.w, height: 12.h),
                SizedBox(height: 12.h),
                BaseShimmer(width: 90.w, height: 20.h),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          BaseShimmer(width: 80.w, height: 50.h, borderRadius: 15.r),
        ],
      ),
    );
  }
}
