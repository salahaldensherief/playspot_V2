import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../text/app_text.dart';

class LoungeStatusBadge extends StatefulWidget {
  final bool isOpen;
  const LoungeStatusBadge({super.key, required this.isOpen});

  @override
  State<LoungeStatusBadge> createState() => _LoungeStatusBadgeState();
}

class _LoungeStatusBadgeState extends State<LoungeStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isOpen) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LoungeStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOpen ? AppColors.success : AppColors.roomBooked;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: widget.isOpen
                ? ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                    ),
                  )
                : Container(
                    width: 5.w,
                    height: 5.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
          SizedBox(width: 5.w),
          AppText(
            text: (widget.isOpen ? AppStrings.active.tr() : AppStrings.closed.tr()).toUpperCase(),
            fontSize: 8.sp,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}
