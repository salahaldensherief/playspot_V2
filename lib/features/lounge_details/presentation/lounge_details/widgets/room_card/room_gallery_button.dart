import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/full_screen_gallery.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class RoomGalleryButton extends StatelessWidget {
  final RoomModel room;
  final Color themeColor;
  const RoomGalleryButton({super.key, required this.room, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => FullScreenGallery(
                      images: room.images,
                      initialIndex: 0,
                      heroTag: 'room_image_${room.id}',
                    )));
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: themeColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 12.sp, color: themeColor),
            6.horizontalSpace,
            AppText(
                text: AppStrings.viewPhotos.tr(),
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: themeColor),
          ],
        ),
      ),
    );
  }
}
