import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class RoomCardShimmer extends StatelessWidget {
  final double? height;
  const RoomCardShimmer({super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BaseShimmer(width: 80.w, height: 16.h),
              BaseShimmer(width: 50.w, height: 12.h),
            ],
          ),
          SizedBox(height: 20.h),
          BaseShimmer(width: 100.w, height: 12.h),
          SizedBox(height: 8.h),
          BaseShimmer(width: 90.w, height: 12.h),
        ],
      ),
    );
  }
}
