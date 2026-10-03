import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/full_screen_gallery.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'photo_indicator.dart';

class LoungeGalleryAction extends StatelessWidget {
  final LoungeModel? initialLounge;
  final String? heroTag;
  const LoungeGalleryAction({super.key, this.initialLounge, this.heroTag});

  static void openGallery(
    BuildContext context,
    LoungeModel lounge,
    String? heroTag,
  ) {
    if (lounge.galleryImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          images: lounge.galleryImages,
          initialIndex: 0,
          heroTag: heroTag ?? 'lounge_image_${lounge.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.lounge != b.lounge,
        builder: (context, state) {
          final lounge = state.lounge ?? initialLounge;
          if (lounge == null || lounge.galleryImages.isEmpty) {
            return const SizedBox.shrink();
          }
          return IconButton(
            tooltip: AppStrings.viewPhotos.tr(),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: PhotoIndicator(totalImages: lounge.galleryImages.length),
            onPressed: () => openGallery(context, lounge, heroTag),
          );
        },
      );
}
