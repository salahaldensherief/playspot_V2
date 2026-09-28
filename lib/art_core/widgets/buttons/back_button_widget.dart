import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class BackButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;

  const BackButtonWidget({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36.w,
        height: 36.h,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            icon ?? Icons.arrow_back,
            color: color ?? Colors.white,
            size: 20.sp,
          ),
          onPressed: onPressed ??
              () {
                if (context.canPop()) {
                  context.pop();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
        ),
      ),
    );
  }
}
