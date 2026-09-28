import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_sizes.dart';
import 'base_shimmer.dart';

class BookingShimmer extends StatelessWidget {
  const BookingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(AppSizes.screenPadding),
      itemCount: 3,
      separatorBuilder: (context, index) => SizedBox(height: AppSizes.s16),
      itemBuilder: (context, index) {
        return BaseShimmer(
          width: double.infinity,
          height: 180.h,
          borderRadius: 20.r,
        );
      },
    );
  }
}
