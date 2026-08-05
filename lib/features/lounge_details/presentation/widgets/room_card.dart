import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/text/price_widget.dart';
import '../../data/models/room_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final isVR = room.activityNames.any((a) => a.toLowerCase().contains('vr'));
    final isSimulator = room.activityNames.any((a) => a.toLowerCase().contains('simulator'));
    final isVIP = room.spaceType?.toLowerCase().contains('vip') ?? false;
    
    Color themeColor = AppColors.neonBlue;
    if (isVIP) {
      themeColor = AppColors.warning;
    } else if (isVR) {
      themeColor = AppColors.neonPurple;
    } else if (isSimulator) {
      themeColor = AppColors.cyan;
    }

    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final isSelected = state.selectedRoomId == room.id;
        final isBooked = state.bookedRoomIds.contains(room.id);
        final isAvailable = room.isAvailable && !isBooked;

        return GestureDetector(
          onTap: isAvailable
              ? () => context.read<LoungeDetailsCubit>().toggleRoomSelection(room.id)
              : null,
          child: Container(
            margin: EdgeInsets.only(bottom: 16.h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: BoxConstraints(
                minHeight: 125.h,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: themeColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: GlassContainer(
                borderRadius: 24,
                borderOpacity: isSelected ? 0.6 : 0.05,
                borderColor: isSelected ? themeColor : (isAvailable ? Colors.white : AppColors.danger),
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      // Content Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Room Image
                          _buildRoomImage(themeColor, isAvailable),
                          
                          // Room Info
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildActivityIcon(isVR, isSimulator, themeColor),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: AppText(
                                              text: room.getName(isArabic),
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w900,
                                              color: isAvailable ? Colors.white : AppColors.textSecondary,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4.h),
                                      _buildSpaceTypeBadge(isVIP, room.spaceType ?? "OPEN", themeColor),
                                    ],
                                  ),
                                  
                                  // Specs Wrap
                                  Padding(
                                    padding: EdgeInsets.only(top: 8.h),
                                    child: Wrap(
                                      spacing: 10.w,
                                      runSpacing: 4.h,
                                      children: [
                                        _buildSpec(Icons.videogame_asset, room.controllersCount.toString()),
                                        _buildSpec(Icons.tv, room.screenSize),
                                        _buildSpec(Icons.people, room.capacity.toString()),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
  
                          // Price & Selection Area
                          _buildActionArea(isAvailable, isSelected, themeColor),
                        ],
                      ),
  
                      // Booked Overlay
                      if (!isAvailable) _buildBookedOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomImage(Color color, bool isAvailable) {
    return Container(
      width: 100.w,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(24.r),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (room.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(24.r)),
              child: Opacity(
                opacity: isAvailable ? 0.7 : 0.3,
                child: CachedNetworkImage(
                  imageUrl: room.images.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(child: Icon(Icons.photo, color: color.withOpacity(0.3))),
                  errorWidget: (context, url, error) => Container(color: Colors.white10),
                ),
              ),
            ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppColors.cardBackground.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(bool isAvailable, bool isSelected, Color color) {
    if (!isAvailable) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PriceWidget(
            price: room.pricePerHour,
            fontSize: 18.sp,
            color: color,
          ),
          AppText(
            text: AppStrings.perHour.tr().toUpperCase(),
            fontSize: 7.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 12.h),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSelected ? Icons.check : Icons.add,
              color: isSelected ? AppColors.black : Colors.white,
              size: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityIcon(bool isVR, bool isSimulator, Color color) {
    IconData icon = Icons.sports_esports;
    if (isVR) icon = Icons.view_in_ar;
    if (isSimulator) icon = Icons.directions_car;
    return Icon(icon, color: color, size: 16.sp);
  }

  Widget _buildSpaceTypeBadge(bool isVIP, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: AppText(
        text: label.toUpperCase(),
        fontSize: 8.sp,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }

  Widget _buildSpec(IconData icon, String value) {
    if (value == '0' || value == 'N/A') return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20.sp, color: AppColors.textSecondary.withOpacity(0.5)),
        SizedBox(width: 4.w),
        AppText(
          text: value,
          fontSize: 10.sp,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  Widget _buildBookedOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: AppText(
              text: AppStrings.booked.tr().toUpperCase(),
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
