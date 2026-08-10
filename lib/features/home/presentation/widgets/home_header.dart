import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String currentLocation;
  final List<Map<String, dynamic>> cities;
  final String? selectedCity;
  final int pointsBalance;
  final Function(String?) onCitySelected;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.currentLocation,
    required this.cities,
    required this.selectedCity,
    required this.pointsBalance,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: 16.horizontalPadding + 16.verticalPadding,
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
                      text: AppStrings.heyUser
                          .tr(args: [userName.split(' ').first]),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    4.verticalSpace,
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.neonBlue, size: 14.sp),
                        4.horizontalSpace,
                        Expanded(
                          child: AppText(
                                text: currentLocation.toUpperCase(),
                                fontSize: 10.sp,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              10.horizontalSpace,
              _buildNotificationBell(context),
              10.horizontalSpace,
              _buildPointsBadge(),
            ],
          ),
          20.verticalSpace,
          if (cities.isNotEmpty)
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cities.length + 1,
                separatorBuilder: (context, index) => 10.horizontalSpace,
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
      borderRadius: AppSizes.r12,
      child: Padding(
        padding: 8.horizontalPadding + 6.verticalPadding,
        child: Row(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.warning, size: 16.sp),
            6.horizontalSpace,
            AppText(
              text: "$pointsBalance ${AppStrings.points.tr().toUpperCase()}",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouterKeys.notifications),
      child: GlassContainer(
        borderRadius: AppSizes.r12,
        child: Padding(
          padding: 8.allPadding,
          child: BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              return Stack(
                children: [
                  Icon(
                    TablerIcons.bell,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                  if (state.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 6.w,
                        height: 6.h,
                        decoration: const BoxDecoration(
                          color: AppColors.neonBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonBlue,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
        padding: 16.horizontalPadding + 8.verticalPadding,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue10 : AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderSubtle,
            width: 1.5,
          ),
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
