import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SliverBottomSpacing extends StatelessWidget {
  final double height;

  const SliverBottomSpacing({
    super.key,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: height.h),
    );
  }
}
