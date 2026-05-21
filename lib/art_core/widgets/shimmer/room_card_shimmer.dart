import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class RoomCardShimmer extends StatelessWidget {
  const RoomCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BaseShimmer(width: 80.w, height: 16.h),
              BaseShimmer(width: 50.w, height: 12.h),
            ],
          ),
          const Spacer(),
          BaseShimmer(width: 100.w, height: 12.h),
          SizedBox(height: 8.h),
          BaseShimmer(width: 90.w, height: 12.h),
        ],
      ),
    );
  }
}
