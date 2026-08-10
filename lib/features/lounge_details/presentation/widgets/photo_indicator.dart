import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/text/app_text.dart';

class PhotoIndicator extends StatefulWidget {
  final int? totalImages;
  const PhotoIndicator({super.key, this.totalImages});

  @override
  State<PhotoIndicator> createState() => _PhotoIndicatorState();
}

class _PhotoIndicatorState extends State<PhotoIndicator> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // ابدأ الحركة بعد تأخير بسيط عند دخول الصفحة
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isExpanded = true);
      }
    });

    // ارجع صغره تاني بعد 4 ثواني عشان ميزحمش الشاشة
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isExpanded = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutBack,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25.r),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16.sp),
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            child: Row(
              children: [
                if (_isExpanded) ...[
                  SizedBox(width: 8.w),
                  AppText(
                    text: AppStrings.viewPhotos.tr(),
                    fontSize: 10.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ],
            ),
          ),
          if (widget.totalImages != null && widget.totalImages! > 1) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Container(
                height: 10.h,
                width: 1.w,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            AppText(
              text: "1/${widget.totalImages}",
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ],
        ],
      ),
    );
  }
}
