import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String currentLocation;
  final List<Map<String, dynamic>> cities;
  final String? selectedCity;
  final Function(String?) onCitySelected;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.currentLocation,
    required this.cities,
    required this.selectedCity,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: AppStrings.heyUser.tr(args: [userName]),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: "Orbitron",
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.neonBlue, size: 14.sp),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: AppText(
                            text: currentLocation.toUpperCase(),
                            fontSize: 10.sp,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              _buildPointsBadge(),
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // City Selection Chips
          if (cities.isNotEmpty)
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cities.length + 1,
                separatorBuilder: (context, index) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCityChip(null, AppStrings.all.tr());
                  }
                  final city = cities[index - 1];
                  return _buildCityChip(city['city'], city['city']);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPointsBadge() {
    return GlassContainer(
      borderRadius: 12,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Row(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.warning, size: 16.sp),
            SizedBox(width: 6.w),
            AppText(
              text: "1,250 XP",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityChip(String? cityValue, String label) {
    final isSelected = selectedCity == cityValue;
    
    return GestureDetector(
      onTap: () => onCitySelected(cityValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: .8,
            )
          ] : [],
        ),
        child: Center(
          child: AppText(
            text: label.toUpperCase(),
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
