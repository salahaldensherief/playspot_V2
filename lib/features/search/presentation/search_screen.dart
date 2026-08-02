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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
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
                    itemCount: lounges.length,
                    separatorBuilder: (context, index) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
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

class SearchLoungeCard extends StatelessWidget {
  final LoungeModel lounge;
  const SearchLoungeCard({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          RouterKeys.loungeDetails,
          extra: lounge,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15.r),
            child: CachedNetworkImage(
              imageUrl: lounge.imageUrl,
              width: 140.w,
              height: 140.h,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding:  EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: lounge.name,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppText(
                    text: lounge.location ?? "",
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.warning, size: 16.sp),
                      SizedBox(width: 4.w),
                      AppText(
                        text: lounge.rating.toString(),
                        fontSize: 12.sp,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16.sp),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: AppText(
                          text: "${lounge.distance} ${AppStrings.km.tr()}",
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${lounge.pricePerHour.toInt()} ${AppStrings.egp.tr()}",
                          style: TextStyle(
                            color: AppColors.neonBlue,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Orbitron",
                          ),
                        ),
                        TextSpan(
                          text: AppStrings.perHour.tr(),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),
                   AppText(
                    text: "${lounge.availableRooms} ${AppStrings.ps5RoomsAvailable.tr()}",
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    ),
        );
  }
}
