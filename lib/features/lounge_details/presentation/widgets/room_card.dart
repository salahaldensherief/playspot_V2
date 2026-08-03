import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
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
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final isSelected = state.selectedRoomId == room.id;
        final isBooked = state.bookedRoomIds.contains(room.id);
        final isAvailable = room.isAvailable && !isBooked;

        return GestureDetector(
          onTap: isAvailable
              ? () => context.read<LoungeDetailsCubit>().toggleRoomSelection(
                    room.id,
                  )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.neonBlue
                        : (isAvailable
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.danger.withValues(alpha: 0.3)),
                    width: 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: room.getName(isArabic),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (room.spaceType != null) ...[
                      SizedBox(height: 2.h),
                      AppText(
                        text: room.spaceType!.toUpperCase(),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonPurple,
                      ),
                    ],
                    SizedBox(height: 6.h),
                    _buildIconInfo(
                      Icons.videogame_asset_outlined,
                      "${room.controllersCount} ${AppStrings.controllers.tr()}",
                    ),
                    _buildIconInfo(
                      Icons.tv_outlined,
                      room.screenSize,
                    ),
                    _buildIconInfo(
                      Icons.people_outline,
                      "${room.capacity} Persons",
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PriceWidget(price: room.pricePerHour),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: AppColors.neonBlue,
                            size: 18.sp,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(context, isAvailable),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconInfo(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        children: [
          Icon(icon, size: 12.sp, color: AppColors.textSecondary),
          SizedBox(width: 4.w),
          Expanded(
            child: AppText(
              text: text,
              fontSize: 10.sp,
              color: AppColors.textSecondary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isAvailable) {
    return Positioned.directional(
      textDirection: Directionality.of(context),
      top: -6.h,
      start: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isAvailable
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.danger.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: AppText(
          text: isAvailable ? AppStrings.available.tr() : AppStrings.booked.tr(),
          fontSize: 8.sp,
          color: isAvailable ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
