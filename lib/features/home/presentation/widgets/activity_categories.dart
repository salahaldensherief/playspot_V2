import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/shimmer/circle_category_shimmer.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'category_item.dart';

class ActivityCategories extends StatelessWidget {
  const ActivityCategories({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
        previous.categories != current.categories ||
        previous.selectedCategoryIds != current.selectedCategoryIds,
      builder: (context, state) {
        if (state.categories.isEmpty && state.status == HomeStatus.loading) {
          return const CircleCategoryShimmer();
        }

        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 85.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: state.categories.length,
            separatorBuilder: (context, index) => 12.horizontalSpace,
            itemBuilder: (context, index) {
              final category = state.categories[index];
              final isSelected = state.selectedCategoryIds.contains(category.id);
              return CategoryItem(
                name: category.getName(isArabic),
                icon: category.icon,
                isSelected: isSelected,
                onTap: () => context.read<HomeCubit>().toggleCategory(category.id),
              );
            },
          ),
        );
      },
    );
  }
}
