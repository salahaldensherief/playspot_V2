import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../home/data/models/lounge_model.dart';

class LoungeDetailsAppBar extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeDetailsAppBar({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.h,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.scaffoldBackground,
      elevation: 0,
      leading: Padding(padding: EdgeInsets.all(8.w), child: const BackButtonWidget()),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        title: LayoutBuilder(
          builder: (context, constraints) {
            var top = constraints.biggest.height;
            bool isCollapsed = top < 120.h; 
            return isCollapsed 
              ? AppText(
                  text: lounge.name,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                )
              : const SizedBox.shrink();
          }
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: lounge.imageUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    AppColors.scaffoldBackground.withOpacity(0.8),
                    AppColors.scaffoldBackground,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 45.h,
              left: 16.w,
              right: 16.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: lounge.name,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text: lounge.location ?? "",
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text:
                        "${AppStrings.openHours.tr()} ${_formatTime(lounge.opensAt)} - ${_formatTime(lounge.closesAt)}",
                    fontSize: 12.sp,
                    color: AppColors.neonBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || !time.contains(':')) return time ?? "";
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final timeOfDay = TimeOfDay(hour: hour, minute: minute);

      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final hourOfPeriod = timeOfDay.hourOfPeriod == 0
          ? 12
          : timeOfDay.hourOfPeriod;

      return "$hourOfPeriod $period";
    } catch (e) {
      return time;
    }
  }
}
