import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double borderOpacity;
  final Color? color;
  final Color? borderColor;
  final bool useBorderColorForGradient;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.blur = 12,
    this.borderOpacity = 0.08,
    this.color,
    this.borderColor,
    this.useBorderColorForGradient = true,
    this.shadow,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final gradientBaseColor = useBorderColorForGradient ? (borderColor ?? Colors.white) : Colors.white;
    
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius.r),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(borderRadius.r),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(borderOpacity),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientBaseColor.withOpacity(borderOpacity + 0.02),
                  gradientBaseColor.withOpacity(0.01),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
