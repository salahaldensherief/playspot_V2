import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';

class HomeLoungeSectionHeader extends StatelessWidget {
  const HomeLoungeSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              text: AppStrings.allLounges.tr(),
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const _SortToggle(),
          ],
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.sortType != current.sortType,
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SortItem(
                label: AppStrings.nearest.tr(),
                isSelected: state.sortType == LoungeSortType.nearest,
                onTap: () => context.read<HomeCubit>().changeSortType(
                  LoungeSortType.nearest,
                ),
              ),
              _SortItem(
                label: AppStrings.topRated.tr(),
                isSelected: state.sortType == LoungeSortType.topRated,
                onTap: () => context.read<HomeCubit>().changeSortType(
                  LoungeSortType.topRated,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SortItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: AppText(
          text: label,
          fontSize: 12.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : AppColors.textSecondary,
        ),
      ),
    );
  }
}
