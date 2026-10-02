import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/full_screen_gallery.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class RoomGalleryButton extends StatelessWidget {
  final RoomModel room;
  final Color themeColor;
  const RoomGalleryButton({
    super.key,
    required this.room,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) => AppButton(
    content: ButtonContent(
      label: AppStrings.viewPhotos.tr(),
      icon: Icon(Icons.photo_library_outlined, color: themeColor, size: 20),
    ),
    buttonConfig: ButtonConfig.outlined(
      height: 48 * MediaQuery.textScalerOf(context).scale(1),
      borderColor: themeColor,
      textStyle: TextStyle(fontSize: 14, color: themeColor),
    ),
    behavior: ButtonBehavior.tap(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenGallery(
            images: room.images,
            initialIndex: 0,
            heroTag: 'room_image_${room.id}',
          ),
        ),
      ),
    ),
  );
}
