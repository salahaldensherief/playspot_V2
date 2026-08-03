import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'category_item.dart';

class ActivityCategories extends StatelessWidget {
  const ActivityCategories({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.categories != current.categories,
      builder: (context, state) {
        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 90.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: state.categories.length,
            separatorBuilder: (context, index) => SizedBox(width: 16.w),
            itemBuilder: (context, index) {
              final category = state.categories[index];
              return CategoryItem(
                name: category.name,
                icon: category.icon,
                onTap: () {},
              );
            },
          ),
        );
      },
    );
  }
}
