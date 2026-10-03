import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'lounge_hero_header.dart';
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
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
    buildWhen: (previous, current) => previous.lounge != current.lounge,
    builder: (context, state) {
      final currentLounge = state.lounge ?? lounge;
      return SliverAppBar(
        pinned: true,
        stretch: true,
        expandedHeight: currentLounge == null
            ? null
            : (currentLounge.galleryImages.isEmpty ? 180 : 300) *
                  MediaQuery.textScalerOf(context).scale(1),
        backgroundColor: AppColors.scaffoldBackground,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: BackButtonWidget(),
        ),
        flexibleSpace: currentLounge == null
            ? null
            : FlexibleSpaceBar(
                centerTitle: true,
                title: LayoutBuilder(
                  builder: (context, constraints) => constraints.maxHeight < 120
                      ? LoungeHeaderTitle(initialLounge: currentLounge)
                      : const SizedBox.shrink(),
                ),
                background: Semantics(
                  button: currentLounge.galleryImages.isNotEmpty,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: currentLounge.galleryImages.isEmpty
                        ? null
                        : () => LoungeGalleryAction.openGallery(
                            context,
                            currentLounge,
                            heroTag,
                          ),
                    child: LoungeHeroHeader(
                      lounge: currentLounge,
                      heroTag: heroTag ?? 'lounge_image_${currentLounge.id}',
                    ),
                  ),
                ),
              ),
        actions: [LoungeGalleryAction(initialLounge: lounge, heroTag: heroTag)],
      );
    },
  );
}
