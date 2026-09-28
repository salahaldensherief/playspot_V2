import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.scaffoldBackground,
          border: border ??
              const Border(
                top: BorderSide(color: AppColors.borderDefault),
              ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding ?? EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
            child: child,
          ),
        ),
      ),
    );
  }
}
