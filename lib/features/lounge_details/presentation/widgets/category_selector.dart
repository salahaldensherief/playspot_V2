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
import '../../../home/data/models/category_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 70.h,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.deviceCategories != current.deviceCategories ||
              previous.selectedCategory != current.selectedCategory,
          builder: (context, state) {
            if (state.status == LoungeDetailsStatus.loading) {
              return const CategoryShimmer();
            }
            if (state.deviceCategories.isEmpty) return const SizedBox.shrink();

            final List<dynamic> allOptions = [
              {'id': '', 'nameEn': 'ALL', 'nameAr': 'الكل'},
              ...state.deviceCategories,
            ];

            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
              scrollDirection: Axis.horizontal,
              itemCount: allOptions.length,
              separatorBuilder: (context, index) => SizedBox(width: AppSizes.w12),
              itemBuilder: (context, index) {
                final option = allOptions[index];
                final String id = option is CategoryModel ? option.id : option['id'];
                final String nameEn = option is CategoryModel ? option.nameEn : option['nameEn'];
                final String nameAr = option is CategoryModel ? option.nameAr : option['nameAr'];
                
                final isArabic = context.locale.languageCode == 'ar';
                final isSelected = state.selectedCategory == id;

                return GestureDetector(
                  onTap: () => context
                      .read<LoungeDetailsCubit>()
                      .setCategory(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSizes.w16, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonBlue.withValues(alpha: 0.1)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.r25),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.borderDefault,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: AppText(
                        text: (isArabic ? nameAr : nameEn).toUpperCase(),
                        fontSize: 13.sp,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.textSecondary,
                      ),
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
