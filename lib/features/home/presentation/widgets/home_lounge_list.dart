import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/cards/lounge_card.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';

class HomeLoungeList extends StatelessWidget {
  const HomeLoungeList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.isLoungesLoading != current.isLoungesLoading ||
          previous.status != current.status ||
          previous.nearestLounges != current.nearestLounges ||
          previous.sortType != current.sortType,
      builder: (context, state) {
        if (state.isLoungesLoading ||
            (state.status == HomeStatus.loading &&
                state.nearestLounges.isEmpty)) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: AppLoader(size: 40),
              ),
            ),
          );
        }

        final lounges = state.nearestLounges;

        if (lounges.isEmpty) {
          final hasFilter = state.selectedCity != null || state.selectedCategoryIds.isNotEmpty;
          return SliverToBoxAdapter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                60.verticalSpace,
                Icon(
                  Icons.search_off_rounded,
                  size: 80.sp,
                  color: Colors.white10,
                ),
                20.verticalSpace,
                AppText(
                  text: AppStrings.noLoungesFound.tr(),
                  color: AppColors.textSecondary,
                  fontSize: 16.sp,
                ),
                16.verticalSpace,
                if (hasFilter)
                  AppButton(
                    content: ButtonContent(label: AppStrings.allLounges.tr()),
                    behavior: ButtonBehavior.tap(
                      onTap: () {
                        context.read<HomeCubit>().selectCity(null);
                      },
                    ),
                    buttonConfig: ButtonConfig(
                      height: 40.h,
                      width: 160.w,
                      backgroundColor: Colors.transparent,
                      borderColor: AppColors.neonBlue,
                      isOutlined: true,
                      borderRadius: 12.r,
                    ),
                  )
                else
                  AppButton(
                    content: ButtonContent(label: AppStrings.retry.tr()),
                    behavior: ButtonBehavior.tap(
                      onTap: () => context.read<HomeCubit>().getHomeData(),
                    ),
                    buttonConfig: ButtonConfig(
                      height: 40.h,
                      width: 120.w,
                      backgroundColor: Colors.transparent,
                      borderRadius: 12.r,
                    ),
                  ),
              ],
            ),
          );
        }

        return SliverPadding(
          padding: 16.horizontalPadding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              mainAxisExtent: 215.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final lounge = lounges[index];
              final heroTag = 'lounge_${lounge.id}_main';
              return LoungeCard(
                key: ValueKey(lounge.id),
                lounge: lounge,
                heroTag: heroTag,
                onTap: () {
                  context.pushNamed(
                    RouterKeys.loungeDetails,
                    extra: {'lounge': lounge, 'heroTag': heroTag},
                  );
                },
              );
            }, childCount: lounges.length),
          ),
        );
      },
    );
  }
}
