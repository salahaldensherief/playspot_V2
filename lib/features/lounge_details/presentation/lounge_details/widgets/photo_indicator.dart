import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class PhotoIndicator extends StatefulWidget {
  final int? totalImages;
  const PhotoIndicator({super.key, this.totalImages});

  @override
  State<PhotoIndicator> createState() => _PhotoIndicatorState();
}

class _PhotoIndicatorState extends State<PhotoIndicator> {
  bool _isExpanded = false;
  Timer? _expandTimer;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _expandTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isExpanded = true);
      }
    });

    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.totalImages ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16.sp),
          if (_isExpanded) ...[
            SizedBox(width: 8.w),
            AppText(
              text: AppStrings.viewPhotos.tr(),
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ],
          if (count > 1) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Container(
                height: 10.h,
                width: 1.w,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            AppText(
              text: "1/$count",
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}
