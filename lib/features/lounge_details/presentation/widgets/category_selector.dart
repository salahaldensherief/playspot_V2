import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/shimmer/category_shimmer.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/utils/category_helper.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 60.h,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          builder: (context, state) {
            if (state.status == LoungeDetailsStatus.loading) {
              return const CategoryShimmer();
            }
            if (state.categories.isEmpty) return const SizedBox.shrink();

            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
              scrollDirection: Axis.horizontal,
              itemCount: state.categories.length,
              separatorBuilder: (context, index) => SizedBox(width: AppSizes.w12),
              itemBuilder: (context, index) {
                final category = state.categories[index];
                final isSelected = state.selectedCategory == category;
                final svgPath = CategoryHelper.getSvgPath(category);

                return GestureDetector(
                  onTap: () => context
                      .read<LoungeDetailsCubit>()
                      .setCategory(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSizes.w16, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonBlue.withOpacity(0.05)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.r25),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.borderDefault,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (svgPath != null)
                          SvgIconWidget(
                            path: svgPath,
                            width: 25.w,
                            color: isSelected
                                ? AppColors.neonBlue
                                : AppColors.textSecondary,
                          )
                        else
                          Icon(
                            CategoryHelper.getIcon(category),
                            size: 18.sp,
                            color: isSelected
                                ? AppColors.neonBlue
                                : AppColors.textSecondary,
                          ),
                        SizedBox(width: AppSizes.w8),
                        AppText(
                          text: category.toUpperCase(),
                          fontSize: 14.sp,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.neonBlue
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
