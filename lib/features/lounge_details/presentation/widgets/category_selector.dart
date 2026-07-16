import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': AppStrings.ps5Rooms, 'icon': Icons.videogame_asset_outlined},
      {'name': AppStrings.simulator, 'icon': Icons.speed},
      {'name': AppStrings.billiard, 'icon': Icons.sports_baseball_rounded},
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 60.h,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
          builder: (context, state) {
            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = state.selectedCategory == cat['name'];

                return GestureDetector(
                  onTap: () => context
                      .read<LoungeDetailsCubit>()
                      .setCategory(cat['name'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonBlue.withOpacity(0.05)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(25.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonBlue
                            : AppColors.borderDefault,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 18.sp,
                          color: isSelected
                              ? AppColors.neonBlue
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          text: (cat['name'] as String).tr(),
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
