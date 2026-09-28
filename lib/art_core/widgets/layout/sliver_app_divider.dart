import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_divider.dart';

class SliverAppDivider extends StatelessWidget {
  final double? verticalPadding;
  final Color? color;
  final double horizontalPadding;

  const SliverAppDivider({
    super.key,
    this.verticalPadding,
    this.color,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w),
        child: AppDivider(
          verticalPadding: verticalPadding,
          color: color,
        ),
      ),
    );
  }
}
