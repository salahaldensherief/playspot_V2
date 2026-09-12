import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import '../../../notifications/presentation/notifications_cubit.dart';
import '../../../notifications/presentation/notifications_state.dart';

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

  String _getDisplayName(String fullName) {
    final clean = fullName.trim();
    if (clean.isEmpty) return '';
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleCubit>();
    final displayName = _getDisplayName(userName);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Greeting & Location (Max Horizontal Space) + Points & Notification Bell
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User Greeting & Location (Gets full remaining width)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      text: AppStrings.heyUser.tr(args: [displayName]),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.neonBlue,
                          size: 13.sp,
                        ),
                        SizedBox(width: 4.w),
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

              SizedBox(width: 10.w),

              // Points Badge
              _buildPointsBadge(context),

              SizedBox(width: 8.w),

              // Notification Bell
              _buildNotificationBell(context),
            ],
          ),

          SizedBox(height: 10.h),

          // Row 2: Search Bar + Tournaments Quick Chip (Wide comfortable touch targets)
          Row(
            children: [
              // Search Bar Trigger
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pushNamed(RouterKeys.search),
                  child: GlassContainer(
                    borderRadius: AppSizes.r12,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.search,
                            color: AppColors.textSecondary,
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: AppText(
                              text: AppStrings.searchLoungesHint.tr(),
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // Tournaments Button Chip
              GestureDetector(
                onTap: () => context.pushNamed(RouterKeys.tournaments),
                child: GlassContainer(
                  borderRadius: AppSizes.r12,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TablerIcons.trophy,
                          color: AppColors.neonBlue,
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        AppText(
                          text: AppStrings.tournamentsAndEvents.tr(),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Row 3: City Chips List
          if (cities.isNotEmpty) ...[
            SizedBox(height: 10.h),
            SizedBox(
              height: 32.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cities.length + 1,
                separatorBuilder: (context, index) => SizedBox(width: 8.w),
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
        ],
      ),
    );
  }

  Widget _buildPointsBadge(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouterKeys.pointsHistory),
      child: GlassContainer(
        borderRadius: AppSizes.r12,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.warning, size: 16.sp),
              SizedBox(width: 4.w),
              AppText(
                text: pointsBalance.toString(),
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouterKeys.notifications),
      child: GlassContainer(
        borderRadius: AppSizes.r12,
        child: SizedBox(
          width: 38.w,
          height: 38.h,
          child: BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (previous, current) => previous.unreadCount != current.unreadCount,
            builder: (context, state) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    TablerIcons.bell,
                    color: Colors.white,
                    size: 19.sp,
                  ),
                  if (state.unreadCount > 0)
                    Positioned(
                      right: 8.w,
                      top: 8.h,
                      child: Container(
                        width: 7.w,
                        height: 7.h,
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue10 : AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderSubtle,
            width: 1.5,
          ),
        ),
        child: Center(
          child: AppText(
            text: label.toUpperCase(),
            fontSize: 10.sp,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
