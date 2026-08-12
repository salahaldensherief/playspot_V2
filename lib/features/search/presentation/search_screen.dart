import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/art_core/widgets/shimmer/search_lounge_card_shimmer.dart';
import 'package:playspot/art_core/widgets/cards/search_lounge_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../home/data/models/lounge_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String selectedCategory = "All";
  List<String> get categories => [
    AppStrings.all.tr(),
    AppStrings.openNow.tr(),
    AppStrings.highestRated.tr(),
    AppStrings.nearest.tr()
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            _buildCategories(),
            Expanded(
              child: BlocBuilder<HomeCubit, HomeState>(
                buildWhen: (previous, current) => 
                  previous.status != current.status || 
                  previous.nearestLounges != current.nearestLounges,
                builder: (context, state) {
                  if (state.status == HomeStatus.loading) {
                    return ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: 5,
                      separatorBuilder: (context, index) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) => const SearchLoungeCardShimmer(),
                    );
                  }
                  
                  final lounges = state.nearestLounges; // Logic to filter can be added here
                  
                  return ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: lounges.length + 1,
                    separatorBuilder: (context, index) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      if (index == lounges.length) {
                        return const SafeBottomSpacer();
                      }
                      return SearchLoungeCard(lounge: lounges[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: AppColors.white),
          ),
          Expanded(
            child: AppTextField(
              hint: AppStrings.searchLoungesHint.tr(),
              borderRadius: 25.r,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: SvgIconWidget(
              path: AssetsManager.filter,
              color: AppColors.white,
              width: 20.w,
              height: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w,),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = category),
            child: Container(

              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.transparent : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                  width: .8,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.2),
                    blurRadius: 0,
                    spreadRadius: 0,
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: AppText(
                text: category,
                fontSize: 14.sp,
                color: isSelected ? AppColors.neonBlue : AppColors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}
