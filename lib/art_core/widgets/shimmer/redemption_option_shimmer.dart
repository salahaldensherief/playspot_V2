import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'base_shimmer.dart';

class RedemptionOptionShimmer extends StatelessWidget {
  const RedemptionOptionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: BaseShimmer(
        width: double.infinity,
        height: 100.h,
        borderRadius: 20.r,
      ),
    );
  }
}
