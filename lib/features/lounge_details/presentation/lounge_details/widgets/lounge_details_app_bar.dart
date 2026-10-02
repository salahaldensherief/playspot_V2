import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_header_title.dart';
import 'lounge_gallery_action.dart';

class LoungeDetailsAppBar extends StatelessWidget {
  final LoungeModel? lounge;
  final String? heroTag;
  const LoungeDetailsAppBar({super.key, this.lounge, this.heroTag});

  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    backgroundColor: AppColors.scaffoldBackground,
    leadingWidth: 64,
    leading: const Padding(
      padding: EdgeInsets.all(8),
      child: BackButtonWidget(),
    ),
    title: LoungeHeaderTitle(initialLounge: lounge),
    actions: [LoungeGalleryAction(initialLounge: lounge, heroTag: heroTag)],
  );
}
