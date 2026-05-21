import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class ExtraShimmer extends StatelessWidget {
  const ExtraShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            BaseShimmer(width: 30.w, height: 30.h),
            SizedBox(width: 16.w),
            BaseShimmer(width: 100.w, height: 18.h),
            const Spacer(),
            BaseShimmer(width: 20.w, height: 20.h),
          ],
        ),
      ),
    );
  }
}
