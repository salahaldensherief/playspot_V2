import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/back_button_widget.dart';
import '../../../../art_core/utils/extensions/date_time_extensions.dart';
import '../../../../art_core/widgets/layout/full_screen_gallery.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../home/data/models/lounge_model.dart';

class LoungeDetailsAppBar extends StatelessWidget {
  final LoungeModel lounge;
  final String? heroTag;

  const LoungeDetailsAppBar({super.key, required this.lounge, this.heroTag});

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
        title: LayoutBuilder(builder: (context, constraints) {
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
        }),
        background: GestureDetector(
          onTap: () => _openImageGallery(context),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag ?? 'lounge_image_${lounge.id}',
                child: CachedNetworkImage(
                  imageUrl: lounge.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
              if (lounge.images != null && lounge.images!.length > 1)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: 55.h,
                  end: 16.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library,
                            color: Colors.white, size: 14.sp),
                        SizedBox(width: 6.w),
                        AppText(
                          text: "1/${lounge.images!.length}",
                          fontSize: 10.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
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
              Positioned.directional(
                textDirection: Directionality.of(context),
                bottom: 45.h,
                start: 16.w,
                end: 16.w,
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
                          "${AppStrings.openHours.tr()} ${lounge.opensAt.to12HourFormat()} - ${lounge.closesAt.to12HourFormat()}",
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
      ),
    );
  }

  void _openImageGallery(BuildContext context) {
    final allImages = <String>[lounge.imageUrl];
    if (lounge.images != null) {
      for (var img in lounge.images!) {
        if (img != lounge.imageUrl) {
          allImages.add(img);
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          images: allImages,
          initialIndex: 0,
          heroTag: 'lounge_image_${lounge.id}',
        ),
      ),
    );
  }
}

